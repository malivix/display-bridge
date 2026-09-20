import json,tempfile,unittest,importlib.util
from pathlib import Path
from unittest.mock import patch
import brightness_presets as presets
from monitor_controls import apply_brightness,inspect_brightness

class BrightnessPresets(unittest.TestCase):
    config={'host':'A','keys':{'pg':'p','benq':'b'},'ddc_identifiers':{'pg':'one','benq':'two'}}
    def test_store_preserves_other_monitor_and_rejects_stale_revision(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'brightness.json';cfg=self.config
            entry=presets.save(path,cfg,'Reading','pg',{'value':30,'maximum':100})
            presets.save(path,cfg,'Reading','benq',{'value':15,'maximum':50})
            self.assertEqual(path.stat().st_mode&0o777,0o600)
            with self.assertRaises(ValueError):presets.save(path,cfg,'Reading','pg',{'value':40,'maximum':100})
            presets.save(path,cfg,'Reading','pg',{'value':40,'maximum':100},True)
            before=path.read_bytes()
            with self.assertRaises(ValueError):presets.remove(path,cfg,'Reading','pg',presets.revision(entry))
            self.assertEqual(path.read_bytes(),before)
            current=next(e for e in presets.read(path,cfg)['presets'] if e['monitor']=='pg')
            presets.remove(path,cfg,'Reading','pg',presets.revision(current))
            self.assertEqual([e['monitor'] for e in presets.read(path,cfg)['presets']],['benq'])
            with self.assertRaises(ValueError):presets.read(path,dict(cfg,host='B'))

    def test_corrupt_or_failed_writes_preserve_original(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'brightness.json'
            for raw in (b'{broken',b'x'*(128*1024+1)):
                path.write_bytes(raw)
                with self.assertRaises(ValueError):presets.save(path,self.config,'Reading','pg',{'value':30,'maximum':100})
                self.assertEqual(path.read_bytes(),raw)
            path.unlink();presets.save(path,self.config,'Reading','pg',{'value':30,'maximum':100})
            before=path.read_bytes()
            with patch.object(presets.os,'replace',side_effect=OSError('injected')):
                with self.assertRaises(OSError):presets.save(path,self.config,'Evening','pg',{'value':10,'maximum':100})
            self.assertEqual(path.read_bytes(),before)

    def test_invalid_entries_and_store_limit_preserve_saved_data(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'brightness.json'
            for i in range(20):presets.save(path,self.config,str(i),'pg',{'value':20,'maximum':100})
            before=path.read_bytes()
            for reading in ({'value':True,'maximum':100},{'value':101,'maximum':100},{'value':0,'maximum':0}):
                with self.assertRaises(ValueError):presets.save(path,self.config,'0','pg',reading,True)
                self.assertEqual(path.read_bytes(),before)
            with self.assertRaises(ValueError):presets.save(path,self.config,'extra','pg',{'value':10,'maximum':50})
            self.assertEqual(path.read_bytes(),before)

    def request(self,inputs=(19,19,19),maximum=50,current=30,readback=None):
        inputs=iter(inputs);value=[current];calls=[]
        def request(action,feature,new=None):
            calls.append((action,feature,new))
            if feature=='input':return str(next(inputs))
            self.assertEqual(feature,'luminance')
            if action=='max':return str(maximum)
            if action=='set':value[0]=new;return ''
            return str(readback if readback is not None and any(c[0]=='set' for c in calls) else value[0])
        return request,calls

    def test_recall_checks_range_ownership_and_one_write(self):
        for kwargs in ({'inputs':(15,)},{'inputs':(19,15)}, {'maximum':100}):
            request,calls=self.request(**kwargs)
            with self.assertRaises(RuntimeError):apply_brightness(self.config,'benq',15,50,request)
            self.assertFalse(any(c[0]=='set' for c in calls))
        for kwargs in ({'inputs':(19,19,15)},{'readback':20}):
            request,calls=self.request(**kwargs)
            with self.assertRaises(RuntimeError):apply_brightness(self.config,'benq',15,50,request)
            self.assertEqual(sum(c[0]=='set' for c in calls),1)
        request,calls=self.request(current=15)
        self.assertFalse(apply_brightness(self.config,'benq',15,50,request)['changed'])
        self.assertFalse(any(c[0]=='set' for c in calls))
        request,calls=self.request()
        self.assertEqual(apply_brightness(self.config,'benq',15,50,request)['percent'],30)

    def test_capture_reads_only_brightness(self):
        request,calls=self.request(inputs=(19,19))
        self.assertEqual(inspect_brightness(self.config,'benq',request),{'value':30,'maximum':50})
        self.assertFalse(any(c[0]=='set' for c in calls))


class BrightnessCLI(unittest.TestCase):
    def test_save_apply_list_remove_use_existing_guards(self):
        spec=importlib.util.spec_from_file_location('brightness_controller',Path(__file__).resolve().parents[2]/'display-auto.py')
        c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            cfg=dict(BrightnessPresets.config,version=c.VERSION,poll_interval=.25,m1ddc='synthetic-ddc',baseline={'screens':[{'key':'p'},{'key':'b'}]})
            (root/'config.json').write_text(json.dumps(cfg));(root/'baseline.json').write_text(json.dumps(cfg['baseline']))
            value=[30];writes=[]
            def command(args,*rest):
                action,feature=args[3:5]
                if feature=='input':return '19'
                self.assertEqual(feature,'luminance')
                if action=='set':value[0]=int(args[5]);writes.append(value[0]);return ''
                return str(50 if action=='max' else value[0])
            def run(action,*extra):
                with patch.object(c.sys,'argv',['display-auto.py',action,'--monitor','benq',*extra]),patch('builtins.print'):
                    c.main()
            with patch.object(c,'ROOT',root),patch.object(c,'CONFIG',root/'config.json'),patch.object(c,'BASELINE',root/'baseline.json'),patch.object(c,'read_control',return_value={}),patch.object(c,'verify_setup') as setup,patch.object(c,'command',side_effect=command) as hardware,patch.object(c.time,'sleep'):
                run('brightness-save','--preset','Reading')
                self.assertEqual(writes,[])
                entry=presets.read(root/'brightness-presets.json',cfg)['presets'][0]
                revision=presets.revision(entry);value[0]=40
                run('brightness-apply','--preset','Reading','--fingerprint',revision)
                self.assertEqual(writes,[30])
                hardware.reset_mock();setup.reset_mock()
                run('brightness-list')
                run('brightness-remove','--preset','Reading','--fingerprint',revision)
                hardware.assert_not_called();setup.assert_not_called()
                self.assertEqual(presets.read(root/'brightness-presets.json',cfg)['presets'],[])
                with patch.object(c,'read_control',return_value={'paused':True}):
                    with self.assertRaises(RuntimeError):run('brightness-save','--preset','Blocked')
                hardware.assert_not_called()
