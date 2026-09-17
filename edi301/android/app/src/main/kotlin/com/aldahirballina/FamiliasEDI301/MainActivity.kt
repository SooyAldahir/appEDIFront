package com.aldahirballina.FamiliasEDI301

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth necesita una FragmentActivity para poder mostrar el diálogo
// biométrico del sistema. Con FlutterActivity (la clase por defecto) la
// autenticación falla en Android con un error de tipo de actividad.
class MainActivity : FlutterFragmentActivity()
