import copy,json,unittest
from pathlib import Path
from types import SimpleNamespace
from preview_hardware import ControllerHardware


class AdapterTests(unittest.TestCase):
    def setUp(self):
        self.screens=[];self.public=[];self.metadata={'displays':[]};self.writes=[]
        for key,width,height,x in [('p',1920,1080,0),('b',1920,1280,-1920)]:
            mode={'modeID':1,'width':width,'height':height,'pixelWidth':2*width,'pixelHeight':2*height,'hz':120,'ioFlags':3,'usableForDesktop':True}
            current=dict(mode,key=key,rotation=0,x=x,y=0)
            self.screens.append(current);self.public.append({'current':current,'modes':[mode]})
            self.metadata['displays'].append(dict(current,hdrPreferenceEnabled=False,variableRefresh=False,proMotion=False,modes=[{'modeID':1,'variableRefresh':False,'proMotion':False}]))
        self.config={'host':'A','keys':{'pg':'p','benq':'b'},'ddc_identifiers':{'pg':'uuid=p','benq':'uuid=b'},'baseline':{'screens':self.screens}}
        self.files={'config.json':json.dumps(self.config).encode(),'baseline.json':json.dumps(self.config['baseline']).encode()}
        self.inputs={'pg':17,'benq':19};self.changed=False
        def command(args,*a):
            if args[0]=='layout' and args[1]=='modes':return json.dumps(self.public)
            if args[0]=='metadata':
                if self.changed:self.inputs={'pg':18,'benq':19}
                return json.dumps(self.metadata)
            if args[1]=='apply':self.writes.append(json.loads(Path(args[2]).read_text()));return ''
            raise AssertionError(args)
        self.c=SimpleNamespace(HELPER='layout',MODE_INFO='metadata',INPUTS={'A':{'pg':17,'benq':19}},read_inputs=lambda cfg:self.inputs,layout=lambda:self.screens,command=command,matches=lambda cfg,profile,screens:cfg['baseline']['screens'][0]['modeID']==screens[0]['modeID'])
        self.h=ControllerHardware(self.c,self.config);self.context=self.h.context()
    def test_apply_uses_exact_modes_and_temporary_strict_baseline(self):
        self.h.apply(self.files,self.context)
        self.assertEqual(len(self.writes),1)
        self.assertTrue(all(s['strictMode'] for s in self.writes[0]['screens']))
        self.assertTrue(self.h.verify(self.files,self.context))
    def test_mode_changed_to_vrr_is_not_written(self):
        self.metadata['displays'][0]['modes'][0]['variableRefresh']=True
        with self.assertRaises(RuntimeError):self.h.apply(self.files,self.context)
        self.assertEqual(self.writes,[])
    def test_input_change_after_inventory_prevents_write(self):
        self.changed=True
        with self.assertRaises(RuntimeError):self.h.apply(self.files,self.context)
        self.assertEqual(self.writes,[])
    def test_failed_fixed_refresh_readback_is_not_success(self):
        self.metadata['displays'][0]['variableRefresh']=True
        self.assertFalse(self.h.verify(self.files,self.context))
    def test_identity_substitution_rejected(self):
        files=copy.deepcopy(self.files);cfg=json.loads(files['config.json']);cfg['ddc_identifiers']['pg']='other';files['config.json']=json.dumps(cfg).encode()
        with self.assertRaises(ValueError):self.h.apply(files,self.context)
        self.assertEqual(self.writes,[])
    def test_sensor_disagreement_defers_preview(self):
        cfg=copy.deepcopy(self.config);cfg['rotation']={'enabled':True};self.c.read_rotation=lambda *a:90
        h=ControllerHardware(self.c,cfg)
        with self.assertRaisesRegex(RuntimeError,'orientation is changing'):h.context()
    def test_fixed_original_can_be_restored_from_vrr_drift(self):
        self.metadata['displays'][0]['modes'][0]['variableRefresh']=True
        fixed=dict(self.public[0]['modes'][0],modeID=2)
        self.public[0]['modes'].append(fixed)
        self.metadata['displays'][0]['modes'].append({'modeID':2,'variableRefresh':False,'proMotion':False})
        cfg=copy.deepcopy(self.config);cfg['baseline']['screens'][0]['modeID']=2
        files={'config.json':json.dumps(cfg).encode(),'baseline.json':json.dumps(cfg['baseline']).encode()}
        self.h.apply(files,self.context)
        self.assertEqual(self.writes[0]['screens'][0]['modeID'],2)


if __name__=='__main__':unittest.main()
