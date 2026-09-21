import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from test_controller import c


class MonitorCLI(unittest.TestCase):
    def test_every_advertised_size_identifier_reaches_preview_service(self):
        from preview_service import LABELS
        for size in LABELS:
            with patch('sys.argv',['display-auto','preview-start','--size',size]),patch('preview_service.enqueue',return_value={}) as enqueue,contextlib.redirect_stdout(io.StringIO()):
                c.main()
                self.assertEqual(enqueue.call_args.args[1:3],('start',size))

    def test_percent_command_uses_setup_guard_and_confirmed_hardware_range(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);config=root/'config.json'
            config.write_text(json.dumps({'host':'A','m1ddc':'fixture-ddc','ddc_identifiers':{'benq':'fixture'}}))
            value=[37];writes=[]
            def command(args,*extra):
                action,feature=args[3:5]
                if feature=='input':return '19'
                if action=='max':return '50'
                if action=='set':value[0]=int(args[5]);writes.append(value[0]);return ''
                return str(value[0])
            with patch.object(c,'ROOT',root),patch.object(c,'CONFIG',config),patch.object(c,'validate_config'),patch.object(c,'verify_setup') as verify,patch.object(c,'read_control',return_value={}),patch.object(c,'command',side_effect=command),patch.object(c.time,'sleep'),patch('sys.argv',['display-auto','monitor-set','--monitor','benq','--feature','luminance','--percent','75']),contextlib.redirect_stdout(io.StringIO()) as output:
                c.main()
            verify.assert_called_once()
            self.assertEqual(writes,[38])
            self.assertEqual(json.loads(output.getvalue())['percent'],76)
