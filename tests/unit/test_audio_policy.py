import unittest
from audio_policy import route

class AudioRoutingTests(unittest.TestCase):
    def setUp(self):
        self.audio={'enabled':True,'pg':'p','benq':'b','fallback':'internal'}
        self.devices=[dict(uid=x,alive=True,default=x=='p',system=x=='p') for x in ['p','b','internal','headset']]
    def test_visible_monitor_and_both_away(self):
        self.assertEqual(route(self.audio,'benq',self.devices),('b','both'))
        self.assertEqual(route(self.audio,'away',self.devices),('internal','both'))
    def test_pg_preferred_without_repeated_writes(self):
        self.assertIsNone(route(self.audio,'extended',self.devices))
        self.devices[0]['default']=False;self.devices[1]['default']=True
        self.assertEqual(route(self.audio,'extended',self.devices),('p','both'))
    def test_external_manual_output_preserved(self):
        self.devices[0]['default']=False;self.devices[3]['default']=True
        for profile in ['extended','pg','benq','away']:
            self.assertIsNone(route(self.audio,profile,self.devices))
    def test_separate_external_alert_output_preserved(self):
        self.devices[0]['system']=False;self.devices[3]['system']=True
        self.assertEqual(route(self.audio,'benq',self.devices),('b','output'))
    def test_unknown_and_disabled_do_not_write(self):
        self.assertIsNone(route(self.audio,'unknown',self.devices))
        self.assertIsNone(route({},'benq',self.devices))
    def test_missing_output_is_not_guessed(self):
        self.devices[1]['alive']=False
        with self.assertRaises(RuntimeError):route(self.audio,'benq',self.devices)
    def test_missing_default_is_not_guessed(self):
        self.devices[0]['default']=False
        with self.assertRaises(RuntimeError):route(self.audio,'benq',self.devices)

    def test_alerts_follow_even_if_output_already_correct(self):
        self.devices[0]['system']=False;self.devices[1]['system']=True
        self.assertEqual(route(self.audio,'extended',self.devices),('p','both'))

if __name__=='__main__':unittest.main()
