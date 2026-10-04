const allInjectionSites = [
  'Stomach - Upper Left',
  'Stomach - Upper Mid',
  'Stomach - Upper Right',
  'Stomach - Lower Left',
  'Stomach - Lower Mid',
  'Stomach - Lower Right',
  'Thigh - Left',
  'Thigh - Right',
  'Arm - Left',
  'Arm - Right',
  'Buttock - Left',
  'Buttock - Right',
];

const defaultRotation = [
  'Stomach - Upper Left',
  'Stomach - Upper Mid',
  'Stomach - Upper Right',
  'Stomach - Lower Left',
  'Stomach - Lower Mid',
  'Stomach - Lower Right',
];

/// The site after [lastSite] in [rotation], wrapping around. Falls back to the
/// first site when the last one isn't part of the rotation.
String? nextSite(List<String> rotation, String? lastSite) {
  if (rotation.isEmpty) return null;
  final i = lastSite == null ? -1 : rotation.indexOf(lastSite);
  return rotation[(i + 1) % rotation.length];
}
