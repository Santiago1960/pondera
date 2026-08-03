String defaultLicenseOutputPath(String requestPath) {
  const extension = '.pondera-request';
  if (requestPath.endsWith(extension)) {
    return '${requestPath.substring(0, requestPath.length - extension.length)}.pondera-license';
  }
  return '$requestPath.pondera-license';
}
