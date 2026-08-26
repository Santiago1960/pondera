String defaultLicenseOutputPath(String requestPath) {
  const extension = '.bitgenial-request';
  if (requestPath.endsWith(extension)) {
    return '${requestPath.substring(0, requestPath.length - extension.length)}.bitgenial-license';
  }
  return '$requestPath.bitgenial-license';
}
