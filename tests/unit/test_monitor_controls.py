import unittest
from monitor_controls import adjust,number,inspect,set_percent


class Controls(unittest.TestCase):
    def test_inspection_never_writes_and_reports_native_range(self):
        def request(action,feature):
            self.assertIn(action,('get','max'))
            return str(19 if feature=='input' else (50 if action=='max' else 37))
        result=inspect({'host':'A'},'benq',request)
        self.assertEqual(result['settings']['volume']['percent'],74)
        self.assertTrue(result['read_only'])

    def test_inspection_discards_reading_if_input_changes(self):
        inputs=iter([19,15])
        def request(action,feature):
            return str(next(inputs) if feature=='input' else (100 if action=='max' else 70))
        with self.assertRaisesRegex(RuntimeError,'Input changed'):inspect({'host':'A'},'benq',request)

    def run_adjust(self,maximum,current,step=5,inputs=None,actual=None,role='benq',host='A'):
        calls=[];values=iter(inputs or [19,19,19]);setting=[current]
        def request(action,feature,value=None):
            calls.append((action,feature,value))
            if feature=='input':return str(next(values))
            if action=='max':return str(maximum)
            if action=='set':setting[0]=value;return ''
            return str(setting[0] if actual is None or not any(c[0]=='set' for c in calls) else actual)
        self.calls=calls
        return adjust({'host':host},role,'volume',step,request)

    def test_percent_target_uses_live_range_and_one_confirmed_write(self):
        calls=[];value=[10]
        def request(action,feature,target=None):
            calls.append((action,feature,target))
            if feature=='input':return '19'
            if action=='max':return '50'
            if action=='set':value[0]=target;return ''
            return str(value[0])
        result=set_percent({'host':'A'},'benq','luminance',75,request)
        self.assertEqual(result['value'],38)
        self.assertEqual(result['percent'],76)  # Nearest hardware step, not an invented 75% readback.
        self.assertEqual(sum(call[0]=='set' for call in calls),1)
        calls.clear()
        self.assertFalse(set_percent({'host':'A'},'benq','luminance',76,request)['changed'])
        self.assertFalse(any(call[0]=='set' for call in calls))

    def test_invalid_percent_never_contacts_monitor(self):
        for value in (True,-1,101,50.0,'50',None):
            with self.assertRaises(ValueError):
                set_percent({'host':'A'},'benq','luminance',value,lambda *a:self.fail('Unexpected hardware request'))

    def test_percent_target_stops_on_input_loss(self):
        for inputs,expected_writes in [([15],0),([19,15],0),([19,19,15],1)]:
            source=iter(inputs);writes=[]
            def request(action,feature,value=None):
                if feature=='input':return str(next(source))
                if action=='max':return '100'
                if action=='set':writes.append(value);return ''
                return '20'
            with self.assertRaises(RuntimeError):set_percent({'host':'A'},'benq','luminance',50,request)
            self.assertEqual(len(writes),expected_writes)

    def test_benq_uses_real_range(self):
        self.assertEqual(self.run_adjust(50,37)['value'],40)
        self.assertEqual(self.run_adjust(100,36)['value'],41)

    def test_clamp_and_no_write_at_limit(self):
        self.assertEqual(self.run_adjust(50,49)['value'],50)
        self.assertFalse(self.run_adjust(50,50)['changed'])
        self.assertFalse(any(c[0]=='set' for c in self.calls))
        self.assertEqual(self.run_adjust(50,1,-5)['value'],0)

    def test_inactive_or_switched_monitor_never_written(self):
        for values in ([15],[19,15]):
            with self.assertRaises(RuntimeError):self.run_adjust(50,37,inputs=values)
            self.assertFalse(any(c[0]=='set' for c in self.calls))

    def test_post_write_switch_and_mismatch_are_not_retried(self):
        for kwargs in ({'inputs':[19,19,15]},{'actual':37}):
            with self.assertRaises(RuntimeError):self.run_adjust(50,37,**kwargs)
            self.assertEqual(sum(c[0]=='set' for c in self.calls),1)

    def test_mac_b_mapping(self):
        self.assertEqual(self.run_adjust(50,37,inputs=[15]*3,host='B')['value'],40)

    def test_invalid_range_and_response(self):
        for maximum,current in [(0,0),(50,51)]:
            with self.assertRaises(ValueError):self.run_adjust(maximum,current)
            self.assertFalse(any(c[0]=='set' for c in self.calls))
        for value in ('-1','1.0','65536','１２',''):
            with self.assertRaises(ValueError):number(value)


if __name__=='__main__':unittest.main()
