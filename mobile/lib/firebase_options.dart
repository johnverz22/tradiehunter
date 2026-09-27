import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for linux.');
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCNrba2doZ1IAnw0JhBta723VDL9JuQaJE',
    appId: '1:951181066529:web:b2a40c24281469f557be60',
    messagingSenderId: '951181066529',
    projectId: 'fixo-dev-75df4',
    authDomain: 'fixo-dev-75df4.firebaseapp.com',
    storageBucket: 'fixo-dev-75df4.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC2p9pkVHHmp2klyX_oOHzLrbTJWl-0s50',
    appId: '1:951181066529:android:ad5056fdb530673c57be60',
    messagingSenderId: '951181066529',
    projectId: 'fixo-dev-75df4',
    storageBucket: 'fixo-dev-75df4.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAUux6O1YykdhhJVdqZbpe34DQLlYk7vIs',
    appId: '1:951181066529:ios:6b0e7ca73d982b2b57be60',
    messagingSenderId: '951181066529',
    projectId: 'fixo-dev-75df4',
    storageBucket: 'fixo-dev-75df4.firebasestorage.app',
    androidClientId: '951181066529-qtdomsvfngs18581g3j4cs11jsr7267h.apps.googleusercontent.com',
    iosClientId: '951181066529-plpht1sdoj0ttjqc1bjma68vas3mikcq.apps.googleusercontent.com',
    iosBundleId: 'nz.co.fixo.fixo',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAUux6O1YykdhhJVdqZbpe34DQLlYk7vIs',
    appId: '1:951181066529:ios:6b0e7ca73d982b2b57be60',
    messagingSenderId: '951181066529',
    projectId: 'fixo-dev-75df4',
    storageBucket: 'fixo-dev-75df4.firebasestorage.app',
    iosBundleId: 'nz.co.fixo.fixo',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCNrba2doZ1IAnw0JhBta723VDL9JuQaJE',
    appId: '1:951181066529:web:9fe3826dc5ab7a1f57be60',
    messagingSenderId: '951181066529',
    projectId: 'fixo-dev-75df4',
    authDomain: 'fixo-dev-75df4.firebaseapp.com',
    storageBucket: 'fixo-dev-75df4.firebasestorage.app',
  );
}
