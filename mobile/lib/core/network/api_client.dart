import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'api_exception.dart';

class ApiClient {
  late final Dio dio;

  // Token yenileme sirasinda bekleyen istekler
  bool _yenileniyor = false;
  final List<({RequestOptions options, ErrorInterceptorHandler handler})> _bekleyenler = [];

  // Oturum tamamen kapandiginda tetiklenir - router giris ekranina yonlendirir
  void Function()? oturumKapandi;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiUrl,
        connectTimeout: AppConfig.baglantiSuresi,
        receiveTimeout: AppConfig.yanitSuresi,
        headers: {'Content-Type': 'application/json'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _istekOncesi,
        onResponse: _yanitSonrasi,
        onError: _hataDurumunda,
      ),
    );
  }

  Future<void> _istekOncesi(RequestOptions options, RequestInterceptorHandler handler) async {
    // Refresh ve login isteklerine token eklenmez
    final tokensiz = options.path.contains('/auth/refresh') ||
        options.path.contains('/auth/login') ||
        options.path.contains('/auth/register');

    if (!tokensiz) {
      final token = await SecureStorage.accessTokenAl();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  void _yanitSonrasi(Response response, ResponseInterceptorHandler handler) {
    final durum = response.statusCode ?? 500;

    // validateStatus 500'un altini gecirdigi icin 4xx'leri burada yakaliyoruz
    if (durum >= 400) {
      final hata = _hataCevir(response);

      // 401 ve token suresi dolmussa yenileme akisina girecek
      if (durum == 401 && _yenilenebilirMi(response)) {
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
          ),
        );
        return;
      }

      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: hata,
          type: DioExceptionType.badResponse,
        ),
      );
      return;
    }

    handler.next(response);
  }

  bool _yenilenebilirMi(Response response) {
    final kod = response.data?['error']?['code'];
    return kod == 'TOKEN_EXPIRED';
  }

  Future<void> _hataDurumunda(DioException err, ErrorInterceptorHandler handler) async {
    final durum = err.response?.statusCode;

    // Token suresi dolduysa yenileyip istegi tekrarla
    if (durum == 401 &&
        err.response != null &&
        _yenilenebilirMi(err.response!) &&
        !err.requestOptions.path.contains('/auth/refresh')) {
      await _tokenYenileVeTekrarla(err, handler);
      return;
    }

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: ApiException(
            message: 'Sunucuya ulasilamiyor, baglantinizi kontrol edin',
            code: 'TIMEOUT',
          ),
        ),
      );
      return;
    }

    if (err.type == DioExceptionType.connectionError) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: ApiException(
            message: 'Internet baglantisi yok',
            code: 'NETWORK_ERROR',
          ),
        ),
      );
      return;
    }

    if (err.error is ApiException) {
      handler.reject(err);
      return;
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: err.response != null
            ? _hataCevir(err.response!)
            : ApiException(message: 'Beklenmeyen bir hata olustu', code: 'UNKNOWN'),
      ),
    );
  }

  Future<void> _tokenYenileVeTekrarla(DioException err, ErrorInterceptorHandler handler) async {
    // Baska bir istek zaten yeniliyorsa kuyruga al
    if (_yenileniyor) {
      _bekleyenler.add((options: err.requestOptions, handler: handler));
      return;
    }

    _yenileniyor = true;

    try {
      final refreshToken = await SecureStorage.refreshTokenAl();

      if (refreshToken == null) {
        await _oturumuKapat(err, handler);
        return;
      }

      // Yenileme istegi interceptor'dan gecmemeli, ayri bir Dio kullaniyoruz
      final temizDio = Dio(BaseOptions(baseUrl: AppConfig.apiUrl));
      final yanit = await temizDio.post('/auth/refresh', data: {'refreshToken': refreshToken});

      final veri = yanit.data['data'];
      await SecureStorage.tokenKaydet(
        accessToken: veri['accessToken'],
        refreshToken: veri['refreshToken'],
      );

      _yenileniyor = false;

      // Basarisiz olan istegi tekrarla
      await _istegiTekrarla(err.requestOptions, handler);

      // Kuyruktakileri de tekrarla
      final kuyruk = List.of(_bekleyenler);
      _bekleyenler.clear();

      for (final bekleyen in kuyruk) {
        await _istegiTekrarla(bekleyen.options, bekleyen.handler);
      }
    } catch (_) {
      _yenileniyor = false;
      await _oturumuKapat(err, handler);
    }
  }

  Future<void> _istegiTekrarla(RequestOptions options, ErrorInterceptorHandler handler) async {
    try {
      final token = await SecureStorage.accessTokenAl();
      options.headers['Authorization'] = 'Bearer $token';

      final yanit = await dio.fetch(options);
      handler.resolve(yanit);
    } catch (e) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: ApiException(message: 'Istek tekrarlanamadi', code: 'RETRY_FAILED'),
        ),
      );
    }
  }

  Future<void> _oturumuKapat(DioException err, ErrorInterceptorHandler handler) async {
    await SecureStorage.temizle();

    // Kuyruktakileri de reddet
    for (final bekleyen in _bekleyenler) {
      bekleyen.handler.reject(
        DioException(
          requestOptions: bekleyen.options,
          error: ApiException(
            message: 'Oturumunuz sonlandi, tekrar giris yapin',
            code: 'SESSION_EXPIRED',
            statusCode: 401,
          ),
        ),
      );
    }
    _bekleyenler.clear();

    oturumKapandi?.call();

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: ApiException(
          message: 'Oturumunuz sonlandi, tekrar giris yapin',
          code: 'SESSION_EXPIRED',
          statusCode: 401,
        ),
      ),
    );
  }

  ApiException _hataCevir(Response response) {
    final veri = response.data;

    if (veri is Map && veri['error'] != null) {
      final hata = veri['error'];

      Map<String, String>? alanlar;
      if (hata['details'] is List) {
        alanlar = {};
        for (final detay in hata['details']) {
          final alan = detay['field'] as String? ?? '';
          if (alan.isNotEmpty) {
            alanlar[alan] = detay['message'] as String;
          }
        }
      }

      return ApiException(
        message: hata['message'] as String? ?? 'Bir hata olustu',
        code: hata['code'] as String? ?? 'ERROR',
        statusCode: response.statusCode,
        alanHatalari: alanlar,
      );
    }

    return ApiException(
      message: 'Bir hata olustu',
      code: 'UNKNOWN',
      statusCode: response.statusCode,
    );
  }
}