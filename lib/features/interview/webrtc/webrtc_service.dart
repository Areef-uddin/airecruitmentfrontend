import 'webrtc_service_stub.dart'
    if (dart.library.html) 'webrtc_service_web.dart' as impl;
import 'webrtc_service_stub.dart' show WebRTCService;

export 'webrtc_service_stub.dart' show WebRTCService;

WebRTCService createWebRTCService() => impl.getWebRTCService();
