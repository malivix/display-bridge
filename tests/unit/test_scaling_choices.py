import copy,unittest
from scaling_choices import candidates,paired_sizes


class ScalingChoices(unittest.TestCase):
    def test_paired_sizes_do_not_promise_dissimilar_scaling(self):
        report={'displays':{r:{'choices':[{'modeID':1,'current':True,'interface_percent':100},{'modeID':2,'current':False,'interface_percent':v}]} for r,v in [('pg',128),('benq',125)]}}
        self.assertEqual([p['label'] for p in paired_sizes(report)],['Larger interface','Current size'])
        report['displays']['benq']['choices'][1]['interface_percent']=140
        self.assertEqual([p['label'] for p in paired_sizes(report)],['Current size'])
    def fixture(self):
        public=[];private=[]
        for key,width,height in [('p',1920,1080),('b',1920,1280)]:
            mode={'modeID':1,'width':width,'height':height,'pixelWidth':2*width,'pixelHeight':2*height,'hz':120,'usableForDesktop':True}
            current=dict(mode,key=key,rotation=0)
            public.append({'current':current,'modes':[mode,dict(mode,modeID=2)]})
            private.append(dict(current,hdrPreferenceEnabled=False,modes=[{'modeID':1,'variableRefresh':False,'proMotion':False},{'modeID':2,'variableRefresh':True,'proMotion':False}]))
        return public,{'displays':private},{'pg':'p','benq':'b'}
    def test_fixed_120_is_distinguished_from_vrr(self):
        args=self.fixture();before=copy.deepcopy(args);report=candidates(*args)
        self.assertEqual([c['modeID'] for c in report['displays']['pg']['choices']],[1])
        self.assertEqual(args,before)
    def test_unknown_refresh_or_bad_rollback_is_rejected(self):
        for change in ('metadata','hdr','changed','mirror','missing_flags'):
            a,b,k=self.fixture()
            if change=='metadata':b['displays'][0]['metadataError']='unavailable'
            if change=='hdr':b['displays'][0]['hdrPreferenceEnabled']=True
            if change=='changed':b['displays'][0]['modeID']=9
            if change=='mirror':a[0]['current']['mirrorOf']='b'
            if change=='missing_flags':b['displays'][0]['modes'][0].pop('variableRefresh')
            with self.subTest(change=change),self.assertRaises(ValueError):candidates(a,b,k)
    def test_unrelated_or_duplicate_identity_rejected(self):
        for duplicate in (True,False):
            a,b,k=self.fixture();a.append(copy.deepcopy(a[0]))
            if not duplicate:a[-1]['current']['key']='other'
            with self.assertRaises(ValueError):candidates(a,b,k)
    def test_non_hidpi_and_wrong_refresh_excluded(self):
        a,b,k=self.fixture()
        for i,values in enumerate([{'pixelWidth':1920},{'hz':60},{'hz':float('nan')},{'usableForDesktop':False}],3):
            a[0]['modes'].append(dict(a[0]['modes'][0],modeID=i,**values))
            b['displays'][0]['modes'].append({'modeID':i,'variableRefresh':False,'proMotion':False})
        self.assertEqual(len(candidates(a,b,k)['displays']['pg']['choices']),1)


if __name__=='__main__':unittest.main()
