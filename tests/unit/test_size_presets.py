import copy,json,tempfile,unittest
from pathlib import Path
from size_presets import capture,find,read,resolve,save


class PresetTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.path=Path(self.temp.name)/'size-presets.json'
        self.config={'host':'A','keys':{'pg':'synthetic-pg','benq':'synthetic-benq'},'ddc_identifiers':{'pg':1,'benq':2}}
        self.report={'displays':{}}
        for role,w,h in [('pg',1920,1080),('benq',1920,1280)]:
            mode=dict(width=w,height=h,pixelWidth=w*2,pixelHeight=h*2,hz=120,modeID=7,current=True)
            self.report['displays'][role]={'choices':[mode]}
        self.entry=capture('Reading',0,self.report)

    def test_semantic_recall_resolves_new_ids_and_preserves_other_orientation(self):
        save(self.path,self.config,self.entry)
        portrait=copy.deepcopy(self.entry);portrait['rotation']=90
        save(self.path,self.config,portrait)
        store=read(self.path,self.config)
        self.assertEqual(len(store['presets']),2)
        for display in self.report['displays'].values():display['choices'][0]['modeID']=42
        pair=resolve(find(store,'Reading',0),0,self.report)
        self.assertEqual(pair['modes']['pg']['modeID'],42)
        self.assertNotIn('modeID',self.path.read_text())
        self.assertEqual(self.path.stat().st_mode & 0o777,0o600)

    def test_replacement_requires_explicit_intent(self):
        save(self.path,self.config,self.entry);original=self.path.read_bytes()
        with self.assertRaisesRegex(ValueError,'already exists'):save(self.path,self.config,self.entry)
        self.assertEqual(original,self.path.read_bytes())
        save(self.path,self.config,self.entry,replace=True)
        self.assertEqual(len(read(self.path,self.config)['presets']),1)

    def test_enrollment_mismatch_and_corruption_preserve_original(self):
        save(self.path,self.config,self.entry);original=self.path.read_bytes()
        changed=copy.deepcopy(self.config);changed['host']='B'
        with self.assertRaisesRegex(ValueError,'another enrollment'):save(self.path,changed,self.entry,replace=True)
        self.assertEqual(original,self.path.read_bytes())
        for data in [b'{broken',b'{}',b'x'*131073]:
            self.path.write_bytes(data)
            with self.assertRaises(ValueError):save(self.path,self.config,self.entry,replace=True)
            self.assertEqual(data,self.path.read_bytes())

    def test_missing_ambiguous_and_wrong_orientation_are_not_substituted(self):
        with self.assertRaisesRegex(ValueError,'other orientation'):resolve(self.entry,90,self.report)
        pg=self.report['displays']['pg']['choices']
        pg.append(dict(pg[0],modeID=9))
        with self.assertRaisesRegex(ValueError,'ambiguous'):resolve(self.entry,0,self.report)
        pg.clear()
        with self.assertRaisesRegex(ValueError,'unavailable'):resolve(self.entry,0,self.report)

    def test_names_schema_and_size_limits(self):
        for label in ['', ' Reading', 'x'*49, 'a\nb']:
            with self.assertRaises(ValueError):capture(label,0,self.report)
        for i in range(20):save(self.path,self.config,dict(self.entry,name=str(i)))
        original=self.path.read_bytes()
        with self.assertRaisesRegex(ValueError,'count'):save(self.path,self.config,dict(self.entry,name='overflow'))
        self.assertEqual(original,self.path.read_bytes())
        store=json.loads(original);store['schema']=True;self.path.write_text(json.dumps(store))
        with self.assertRaisesRegex(ValueError,'Unsupported'):read(self.path,self.config)
