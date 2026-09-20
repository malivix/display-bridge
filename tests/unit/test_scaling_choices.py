import copy,unittest
from scaling_choices import candidates,paired_sizes,physical_match,physical_size_percent


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
    def test_extreme_numeric_modes_are_excluded_without_overflow(self):
        for values in ({'hz':10**400}, {'width':10**400,'pixelWidth':2*10**400},
                       {'height':True}, {'pixelHeight':65537}):
            with self.subTest(fields=list(values)):
                a,b,k=self.fixture()
                a[0]['modes'].append(dict(a[0]['modes'][0],modeID=3,**values))
                b['displays'][0]['modes'].append({'modeID':3,'variableRefresh':False,'proMotion':False})
                self.assertEqual(len(candidates(a,b,k)['displays']['pg']['choices']),1)

    def test_invalid_current_dimensions_fail_before_size_arithmetic(self):
        for value in (True,0,-1,10**400,1920.0):
            a,b,k=self.fixture()
            a[0]['current']['width']=value;b['displays'][0]['width']=value
            with self.subTest(value_type=type(value).__name__),self.assertRaises(ValueError):
                candidates(a,b,k,require_rollback=False)

    def test_physical_match_preserves_benq_and_handles_portrait(self):
        for portrait in (False,True):
            a,b,k=self.fixture()
            if portrait:
                for mode in [a[1]['current'],*a[1]['modes']]:
                    mode['width'],mode['height']=mode['height'],mode['width']
                    mode['pixelWidth'],mode['pixelHeight']=mode['pixelHeight'],mode['pixelWidth']
                a[1]['current']['rotation']=90
                b['displays'][1].update({f:a[1]['current'][f] for f in ('width','height','pixelWidth','pixelHeight','rotation')})
            a[0]['modes'].append(dict(a[0]['modes'][0],modeID=3,width=3008,height=1692,pixelWidth=6016,pixelHeight=3384))
            b['displays'][0]['modes'].append({'modeID':3,'variableRefresh':False,'proMotion':False})
            report=candidates(a,b,k);before=copy.deepcopy(report);match=physical_match(report)
            self.assertEqual(match['modes']['pg']['modeID'],3)
            self.assertEqual(match['modes']['benq'],report['displays']['benq']['choices'][0])
            self.assertLess(abs(physical_size_percent(match['modes'])-100),5)
            self.assertEqual(report,before)
            self.assertEqual(paired_sizes(report)[-1]['label'],'Match PG size to BenQ')
        report=candidates(*self.fixture())
        self.assertIsNone(physical_match(report))
        self.assertIsNone(physical_size_percent({'pg':{},'benq':{}}))

    def test_match_can_preserve_pg_in_either_benq_orientation(self):
        for portrait in (False,True):
            a,b,k=self.fixture()
            mode=dict(a[1]['modes'][0],modeID=3,width=1248,height=832,pixelWidth=2496,pixelHeight=1664)
            a[1]['modes'].append(mode)
            b['displays'][1]['modes'].append({'modeID':3,'variableRefresh':False,'proMotion':False})
            if portrait:
                for item in [a[1]['current'],*a[1]['modes']]:
                    item['width'],item['height']=item['height'],item['width']
                    item['pixelWidth'],item['pixelHeight']=item['pixelHeight'],item['pixelWidth']
                a[1]['current']['rotation']=90
                b['displays'][1].update({f:a[1]['current'][f] for f in ('width','height','pixelWidth','pixelHeight','rotation')})
            report=candidates(a,b,k);match=physical_match(report,'pg')
            self.assertEqual(match['label'],'Match BenQ size to PG')
            self.assertEqual(match['modes']['benq']['modeID'],3)
            self.assertEqual(match['modes']['pg'],report['displays']['pg']['choices'][0])
            self.assertLess(abs(physical_size_percent(match['modes'])-100),5)
        with self.assertRaises(ValueError):physical_match(report,'other')

    def test_non_hidpi_and_wrong_refresh_excluded(self):
        a,b,k=self.fixture()
        for i,values in enumerate([{'pixelWidth':1920},{'hz':60},{'hz':float('nan')},{'usableForDesktop':False}],3):
            a[0]['modes'].append(dict(a[0]['modes'][0],modeID=i,**values))
            b['displays'][0]['modes'].append({'modeID':i,'variableRefresh':False,'proMotion':False})
        self.assertEqual(len(candidates(a,b,k)['displays']['pg']['choices']),1)


if __name__=='__main__':unittest.main()
