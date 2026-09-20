import copy,json,unittest
from scaling_proposal import build


class Proposals(unittest.TestCase):
    def fixture(self):
        pg={'key':'p','rotation':0,'x':0,'y':0,'width':2048,'height':1152,'pixelWidth':4096,'pixelHeight':2304,'modeID':1,'hz':120,'ioFlags':3}
        benq={'key':'b','rotation':0,'x':-1280,'y':189,'width':1280,'height':853,'pixelWidth':2560,'pixelHeight':1706,'modeID':2,'hz':120,'ioFlags':3}
        choices={}
        for role,current,width,height in [('pg',pg,1600,900),('benq',benq,1024,683)]:
            choices[role]={k:current[k] for k in ('modeID','hz','ioFlags')}
            choices[role].update(width=width,height=height,pixelWidth=2*width,pixelHeight=2*height)
        baseline={'screens':[pg,benq]}
        config={'keys':{'pg':'p','benq':'b'},'baseline':baseline,'rotation':{'enabled':True,'baselines':{'0':baseline,'90':{'preserve':'portrait'}}}}
        report={'displays':{role:{'current':current,'choices':[choices[role]]} for role,current in [('pg',pg),('benq',benq)]}}
        return config,report,{'modes':choices}
    def test_alignment_and_other_orientation_preserved(self):
        args=self.fixture();before=copy.deepcopy(args);files=build(*args)
        config=json.loads(files['config.json']);screens=config['baseline']['screens']
        self.assertEqual(screens[1]['x'],-1024);self.assertEqual(screens[1]['y'],148)
        self.assertEqual(config['rotation']['baselines']['90'],{'preserve':'portrait'})
        self.assertEqual(json.loads(files['baseline.json']),config['baseline'])
        self.assertEqual(json.loads(files['rotation-active.json']),config['baseline'])
        self.assertEqual(args,before)
        self.assertTrue(all(s['strictMode'] for s in screens))
    def test_unknown_arrangement_or_choice_rejected(self):
        for change in ('position','choice'):
            config,report,pair=self.fixture()
            if change=='position':report['displays']['pg']['current']['x']=100
            else:pair=copy.deepcopy(pair);pair['modes']['pg']['modeID']=999
            with self.assertRaises(ValueError):build(config,report,pair)


if __name__=='__main__':unittest.main()
