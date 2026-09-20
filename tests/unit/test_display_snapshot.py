import copy
import unittest
from display_snapshot import report


class DisplaySnapshot(unittest.TestCase):
    def setUp(self):
        self.rows = [{'key':key,'modeID':1,'width':1920,'height':1080,'pixelWidth':3840,'pixelHeight':2160,'rotation':0,'hz':120,'variableRefresh':False,'proMotion':False,'hdrPreferenceEnabled':False} for key in ('p','b')]
        self.config = {'host':'A','keys':{'pg':'p','benq':'b'},'baseline':{'screens':copy.deepcopy(self.rows)}}
        self.metadata = {'displays':self.rows}

    def test_rotation_profiles_validate_before_activation(self):
        from display_snapshot import validate_rotation,rotation_baseline
        cfg=copy.deepcopy(self.config)
        profiles={}
        for angle in (0,90):
            rows=copy.deepcopy(self.rows)
            for row in rows:row.update(x=0,y=0)
            rows[1]['rotation']=angle
            profiles[str(angle)]={'screens':rows}
        cfg['rotation']={'enabled':True,'sensor_map':{'1':0,'2':90},'baselines':profiles}
        validate_rotation(cfg)
        self.assertEqual(rotation_baseline(cfg,90),profiles['90'])
        for field,value in [('key','unfamiliar'),('rotation',0),('width',False),('width',0),('x',2**31),('hz',float('inf')),('modeID',True),('ioFlags',-1),('strictMode','yes'),('mirrorOf','p')]:
            broken=copy.deepcopy(cfg);broken['rotation']['baselines']['90']['screens'][1][field]=value
            with self.subTest(field=field,value=value),self.assertRaises(ValueError):validate_rotation(broken)
        for invalid in [True,180,float('nan')]:
            with self.assertRaises(ValueError):rotation_baseline(cfg,invalid)
        partial=copy.deepcopy(cfg);partial['rotation']['enabled']=False
        del partial['rotation']['baselines']['90']
        validate_rotation(partial)
        with self.assertRaises(ValueError):rotation_baseline(partial,90)
        partial['rotation']['enabled']=True
        with self.assertRaises(ValueError):validate_rotation(partial)
        for mapping in [{'1':True,'2':90},{'sensor':0,'2':90},[]]:
            broken=copy.deepcopy(cfg);broken['rotation']['sensor_map']=mapping
            with self.assertRaises(ValueError):validate_rotation(broken)

    def inspect(self, inputs=None, second=None):
        return report(self.config, inputs or {'pg':17,'benq':19}, self.metadata, second or self.metadata)

    def test_local_modes_and_no_private_identity(self):
        result = self.inspect()
        self.assertTrue(result['displays'][0]['fixed_refresh'])
        self.assertTrue(result['displays'][0]['hidpi'])
        self.assertTrue(result['displays'][0]['saved_mode_matches'])
        self.assertNotIn('key', result['displays'][0]['current'])
        self.assertNotIn('modeID', result['displays'][0]['current'])

    def test_nonlocal_monitor_has_no_current_or_saved_output_claim(self):
        row = self.inspect({'pg':18,'benq':19})['displays'][0]
        self.assertFalse(row['available'])
        self.assertNotIn('current', row)

    def test_changes_and_extra_monitor_rejected(self):
        altered = copy.deepcopy(self.metadata)
        altered['displays'][0]['width'] = 1680
        with self.assertRaises(ValueError): self.inspect(second=altered)
        self.rows.append(dict(self.rows[0], key='other'))
        with self.assertRaises(ValueError): self.inspect()

    def test_unknown_metadata_does_not_claim_fixed_or_hdr(self):
        self.rows[0]['metadataError'] = 'unavailable'
        row = self.inspect()['displays'][0]
        self.assertIsNone(row['fixed_refresh'])
        self.assertIsNone(row['hdr_preference'])

    def test_rotation_baseline_applies_to_both_monitors(self):
        portrait = copy.deepcopy(self.rows)
        portrait[0]['width'] = 1680
        self.rows[1]['rotation'] = 90
        self.config['rotation'] = {'enabled':True, 'baselines':{'90':{'screens':portrait}}}
        result = self.inspect()['displays']
        self.assertEqual(result[0]['saved']['width'], 1680)
        self.assertFalse(result[0]['saved_mode_matches'])

    def test_invalid_numeric_fields_and_no_rotation_baseline(self):
        self.rows[0]['hz'] = 10**1000
        self.rows[0]['width'] = True
        self.config['rotation'] = {'enabled':True, 'baselines':{}}
        result = self.inspect()['displays']
        self.assertIsNone(result[0]['hz'])
        self.assertIsNone(result[0]['current'])
        self.assertIsNone(result[1]['saved'])

class SnapshotCommand(unittest.TestCase):
    def test_input_change_discards_entire_snapshot(self):
        import importlib.util
        import tempfile
        import json
        import sys
        from pathlib import Path
        from contextlib import ExitStack
        from unittest.mock import patch
        spec = importlib.util.spec_from_file_location('snapshot_controller', Path(__file__).resolve().parents[2]/'display-auto.py')
        c = importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
        with tempfile.TemporaryDirectory() as directory, ExitStack() as stack:
            stack.enter_context(patch.object(c, 'ROOT', Path(directory)))
            stack.enter_context(patch.object(sys, 'argv', ['display-auto.py','display-info']))
            stack.enter_context(patch.object(c, 'startup_config', return_value={}))
            stack.enter_context(patch.object(c, 'read_inputs', side_effect=[{'pg':17,'benq':19},{'pg':18,'benq':19}]))
            command = stack.enter_context(patch.object(c, 'command', return_value=json.dumps({'displays':[]})))
            with self.assertRaisesRegex(RuntimeError, 'Inputs changed'):
                c.main()
            self.assertEqual(command.call_count, 2)
            self.assertTrue(all(call.args[0][-1]=='status' for call in command.call_args_list))
