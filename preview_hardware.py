# SPDX-License-Identifier: MIT
"""Exact-mode adapter for the preview runner; daemon integration is separate."""
import copy,json,tempfile
from pathlib import Path
from scaling_choices import candidates
from health_check import mode_checks


class ControllerHardware:
    def __init__(self,controller,config,metadata_helper=None):
        self.c=controller;self.config=copy.deepcopy(config)
        self.metadata_helper=metadata_helper or controller.MODE_INFO

    def context(self):
        c=self.c;inputs=c.read_inputs(self.config)
        if inputs!=c.INPUTS[self.config['host']]:raise RuntimeError('Preview waits for both monitors on this Mac')
        screens=c.layout();by_key={s['key']:s for s in screens}
        if len(screens)!=2 or set(by_key)!=set(self.config['keys'].values()):raise RuntimeError('Saved display topology changed')
        pg=by_key[self.config['keys']['pg']];benq=by_key[self.config['keys']['benq']]
        if pg['rotation']!=0 or benq['rotation'] not in (0,90):raise RuntimeError('Unsupported display orientation')
        if self.config.get('rotation',{}).get('enabled'):
            angle=c.read_rotation(self.config,'extended')
            if angle!=benq['rotation']:raise RuntimeError('Physical orientation is changing; preview waits')
        return {'host':self.config['host'],'keys':self.config['keys'],'ddc_identifiers':self.config['ddc_identifiers'],
                'inputs':inputs,'rotation':benq['rotation']}

    def effective(self,files,context):
        cfg=json.loads(files['config.json']);baseline=json.loads(files['baseline.json'])
        if cfg['baseline']!=baseline:raise ValueError('Proposed configuration and baseline differ')
        for key in ('host','keys','ddc_identifiers'):
            if cfg.get(key)!=self.config.get(key):raise ValueError('Preview must preserve monitor identity and host')
        if cfg.get('rotation',{}).get('enabled'):
            baseline=cfg['rotation']['baselines'].get(str(context['rotation']))
            if not baseline:raise ValueError('No saved baseline for the current orientation')
        if len(baseline['screens'])!=2 or {s['key'] for s in baseline['screens']}!=set(cfg['keys'].values()):
            raise ValueError('Preview baseline identity mismatch')
        cfg['baseline']=copy.deepcopy(baseline)
        for screen in cfg['baseline']['screens']:
            expected=context['rotation'] if screen['key']==cfg['keys']['benq'] else 0
            if screen['rotation']!=expected:raise ValueError('Preview must not rotate a monitor')
            screen['strictMode']=True
        return cfg

    def inspect(self):
        public=json.loads(self.c.command([self.c.HELPER,'modes']))
        metadata=json.loads(self.c.command([self.metadata_helper,'modes']))
        return candidates(public,metadata,self.config['keys'],require_rollback=False)

    def apply(self,files,expected):
        if self.context()!=expected:raise RuntimeError('Preview context changed before mode validation')
        config=self.effective(files,expected);report=self.inspect()
        for screen in config['baseline']['screens']:
            role=next(role for role,key in config['keys'].items() if key==screen['key'])
            matches=[mode for mode in report['displays'][role]['choices'] if all(mode.get(field)==screen.get(field) for field in ('modeID','width','height','pixelWidth','pixelHeight','hz','ioFlags'))]
            if len(matches)!=1:raise RuntimeError('Exact fixed-refresh preview mode is no longer available')
        # Last input/sensor check occurs after mode inventory and before writing.
        if self.context()!=expected:raise RuntimeError('Inputs or orientation changed before applying preview')
        with tempfile.TemporaryDirectory(prefix='display-preview-') as directory:
            path=Path(directory)/'baseline.json';path.write_text(json.dumps(config['baseline']))
            self.c.command([self.c.HELPER,'apply',path,'extended'],8)

    def verify(self,files,expected):
        if self.context()!=expected:return False
        config=self.effective(files,expected)
        if not self.c.matches(config,'extended',self.c.layout()):return False
        metadata=json.loads(self.c.command([self.metadata_helper,'status']))
        checks=mode_checks(config,expected['inputs'],metadata)
        return len(checks)==2 and all(check['status']=='ok' for check in checks) and self.context()==expected
