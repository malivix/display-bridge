import importlib.util,json,os,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from health_check import report,mode_checks
spec=importlib.util.spec_from_file_location('controller_health',(Path(__file__).resolve().parents[2]/'display-auto.py'))
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)

class HealthChecks(unittest.TestCase):
    def modes(self):
        screens=[dict(key=k,width=1280,height=853,pixelWidth=2560,pixelHeight=1706,rotation=0,modeID=67,hz=120) for k in ('p','b')]
        config={'host':'A','keys':{'pg':'p','benq':'b'},'baseline':{'screens':screens}}
        metadata={'displays':[dict(s,variableRefresh=False,proMotion=False,hdrPreferenceEnabled=False) for s in screens]}
        return config,metadata
    def test_mode_check_requires_fixed_refresh_not_numeric_hertz(self):
        config,metadata=self.modes()
        self.assertTrue(all(r['status']=='ok' for r in mode_checks(config,{'pg':17,'benq':19},metadata)))
        metadata['displays'][0]['variableRefresh']=True
        self.assertEqual(mode_checks(config,{'pg':17,'benq':19},metadata)[0]['status'],'warning')
        metadata['displays'][0].pop('variableRefresh')
        self.assertEqual(mode_checks(config,{'pg':17,'benq':19},metadata)[0]['status'],'warning')
    def test_mode_check_warns_on_hdr_wrong_size_or_unavailable_metadata(self):
        for change in ({'hdrPreferenceEnabled':True},{'width':1234},{'metadataError':'unavailable'},{'modeID':68}):
            config,metadata=self.modes();metadata['displays'][0].update(change)
            self.assertEqual(mode_checks(config,{'pg':17,'benq':19},metadata)[0]['status'],'warning')
    def test_mode_check_ignores_monitors_showing_other_mac(self):
        config,metadata=self.modes();metadata['displays'][1]['variableRefresh']=True
        checks=mode_checks(config,{'pg':17,'benq':15},metadata)
        self.assertEqual(len(checks),1);self.assertEqual(checks[0]['status'],'ok')
        self.assertEqual(mode_checks(config,{'pg':18,'benq':15},metadata)[0]['status'],'info')
        config['host']='B'
        checks=mode_checks(config,{'pg':17,'benq':15},metadata)
        self.assertEqual(checks[0]['name'],'BenQ mode');self.assertEqual(checks[0]['status'],'warning')
    def test_mode_check_uses_saved_portrait_baseline(self):
        config,metadata=self.modes();portrait=dict(config['baseline']['screens'][1],width=853,height=1280,pixelWidth=1706,pixelHeight=2560,rotation=90)
        config['rotation']={'enabled':True,'baselines':{'90':{'screens':[config['baseline']['screens'][0],portrait]}}}
        metadata['displays'][1].update(portrait)
        self.assertEqual(mode_checks(config,{'pg':17,'benq':19},metadata)[1]['status'],'ok')
    def test_pg_uses_orientation_specific_saved_size_too(self):
        config,metadata=self.modes()
        pg=dict(config['baseline']['screens'][0],width=1920,height=1080,pixelWidth=3840,pixelHeight=2160,modeID=80)
        benq=dict(config['baseline']['screens'][1],width=853,height=1280,pixelWidth=1706,pixelHeight=2560,rotation=90)
        config['rotation']={'enabled':True,'baselines':{'90':{'screens':[pg,benq]}}}
        metadata['displays'][0].update(pg);metadata['displays'][1].update(benq)
        self.assertTrue(all(row['status']=='ok' for row in mode_checks(config,{'pg':17,'benq':19},metadata)))
        metadata['displays'].append(dict(metadata['displays'][1]))
        self.assertEqual(mode_checks(config,{'pg':17,'benq':19},metadata)[0]['status'],'warning')

    def test_invalid_configuration_never_queries_monitors_or_changes_files(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);(root/'config.json').write_text('{bad')
            before={p.name:p.read_bytes() for p in root.iterdir()}
            with patch.object(c,'read_inputs') as read:
                result=report(root,root,c.VERSION,lambda cfg:None,read)
                read.assert_not_called()
            self.assertTrue(result['read_only']);self.assertEqual(result['status'],'error')
            self.assertEqual(before,{p.name:p.read_bytes() for p in root.iterdir()})
    def test_unknown_inputs_have_actionable_warning_without_mutations(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            for name,data in [('config.json',{}),('health.json',{'pid':os.getpid(),'updated_at':c.time.time(),'version':c.VERSION,'status':'ready'}),('manifest.json',{'source_sha256':[]})]:
                (root/name).write_text(json.dumps(data))
            result=report(root,root,c.VERSION,lambda cfg:None,lambda cfg:{'pg':15,'benq':19})
            inputs=next(x for x in result['checks'] if x['name']=='Monitor inputs')
            self.assertEqual(inputs['status'],'warning')
            self.assertIn('not guessed',inputs['action'])
    def test_check_cli_never_selects_or_writes_rotation_baseline(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);config=root/'config.json';config.write_text(json.dumps({'rotation':{'enabled':True},'host':'A'}))
            with patch.object(c,'ROOT',root),patch.object(c,'CONFIG',config),patch.object(c,'validate_config'),patch.object(c,'read_control',return_value={}),patch.object(c,'select_rotation_baseline') as select,patch.object(c,'read_inputs',return_value={'pg':17,'benq':19}),patch.object(c,'layout',return_value=[]),patch.object(c,'RotatingFileHandler'),patch.object(c.LOG,'addHandler'),patch.object(c.sys,'argv',['display-auto.py','check']),patch('builtins.print'):
                c.main()
                select.assert_not_called()
                self.assertFalse((root/'rotation-active.json').exists())
    def test_restore_rejects_nonlocal_inputs_before_baseline_or_hardware_changes(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);config=root/'config.json';config.write_text(json.dumps({'rotation':{'enabled':True},'host':'A'}))
            with patch.object(c,'ROOT',root),patch.object(c,'CONFIG',config),patch.object(c,'validate_config'),patch.object(c,'read_control',return_value={}),patch.object(c,'select_rotation_baseline') as select,patch.object(c,'read_inputs',return_value={'pg':18,'benq':19}),patch.object(c,'apply') as apply,patch.object(c,'RotatingFileHandler'),patch.object(c.LOG,'addHandler'),patch.object(c.sys,'argv',['display-auto.py','restore']):
                with self.assertRaises(c.InputsChanged):c.main()
                select.assert_not_called();apply.assert_not_called()
    def test_timed_pause_expires_and_indefinite_pause_clears_timer(self):
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'ROOT',Path(temp)),patch.object(c,'CONTROL',Path(temp)/'control.json'),patch.object(c.time,'time',return_value=100),patch('builtins.print'):
            c.control_command('pause-for',15)
            control=c.read_control()
            self.assertTrue(c.automation_paused(control,999))
            self.assertFalse(c.automation_paused(control,1000))
            c.control_command('pause',30)
            self.assertTrue(c.automation_paused(c.read_control(),10000))
            c.control_command('resume',30)
            self.assertFalse(c.automation_paused(c.read_control(),100))
            with self.assertRaises(RuntimeError):c.control_command('pause-for',0)
    def test_expired_pause_allows_audio_repair(self):
        with tempfile.TemporaryDirectory() as temp,patch.object(c,'ROOT',Path(temp)),patch.object(c,'CONTROL',Path(temp)/'control.json'),patch('builtins.print'):
            c.CONTROL.write_text(json.dumps({'paused':True,'pause_until':1}))
            c.control_command('repair-audio',30)
            self.assertIn('repair_token',c.read_control())

if __name__=='__main__':unittest.main()
