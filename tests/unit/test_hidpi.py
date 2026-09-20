import unittest
from hidpi_report import analyze

class HiDPITests(unittest.TestCase):
    def inventory(self, portrait=False):
        current = dict(key='2513:32963:12345', width=1280, height=853,
                       pixelWidth=2560, pixelHeight=1706, rotation=0, hz=120, modeID=67)
        native = dict(width=1920, height=1280, pixelWidth=3840, pixelHeight=2560,
                      hz=120, modeID=145, usableForDesktop=True)
        if portrait:
            current['rotation'] = 90
            for m in (current, native):
                m['width'], m['height'] = m['height'], m['width']
                m['pixelWidth'], m['pixelHeight'] = m['pixelHeight'], m['pixelWidth']
        return [dict(current=current, modes=[native, dict(native, modeID=146)])]

    def test_native_raster_does_not_claim_fixed_refresh(self):
        d = analyze(self.inventory())['displays'][0]
        self.assertEqual(d['current']['sampling'], 'upscaled raster')
        self.assertEqual(len(d['candidates']), 2)
        self.assertEqual(d['candidates'][0]['sampling'], 'native raster')
        self.assertEqual(d['candidates'][0]['content_zoom_to_match_current_percent'], 150)
        self.assertIn('unverified', d['candidates'][0]['refresh_type'])

    def test_portrait_uses_rotated_panel_dimensions(self):
        d = analyze(self.inventory(True))['displays'][0]
        self.assertEqual(d['panel_pixels'], (2560, 3840))
        self.assertEqual(d['candidates'][0]['sampling'], 'native raster')

    def test_filters_wrong_aspect_lowdpi_and_unusable_modes(self):
        inv = self.inventory()
        mode = inv[0]['modes'][0]
        inv[0]['modes'] = [dict(mode, width=1920, height=1080, pixelHeight=2160),
                           dict(mode, pixelWidth=1920), dict(mode, hz=60),
                           dict(mode, usableForDesktop=False)]
        self.assertEqual(analyze(inv)['displays'][0]['candidates'], [])

    def test_same_model_with_another_serial_is_supported(self):
        inv = self.inventory()
        inv[0]['current']['key'] = '2513:32963:54321'
        self.assertTrue(analyze(inv)['displays'][0]['supported'])

    def test_unknown_monitor_is_not_assumed_to_be_benq(self):
        inv = self.inventory(); inv[0]['current']['key'] = 'unknown'
        self.assertFalse(analyze(inv)['displays'][0]['supported'])

if __name__ == '__main__': unittest.main()
