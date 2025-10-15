// Conditional import: on web use the HTML implementation, otherwise use IO stub
export 'download_helper_io.dart'
    if (dart.library.html) 'download_helper_web.dart';
