///
/// 用于加密解密的类
/// 算法：AES/CBC/PKCS7
///
/// created by keng42 @2019-08-14 15:20:51
///

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pointycastle/pointycastle.dart';
import 'package:convert/convert.dart';

class Cbox {
  String key;
  String encoding;

  static const DEFAULT_KEY = '7At16p/dyonmDW3ll9Pl1bmCsWEACxaIzLmyC0ZWGaE=';

  static final base64E = new Base64Encoder();
  static final base64D = new Base64Decoder();

  Cbox({key = DEFAULT_KEY, encoding = 'base64'}) {
    this.key = key;
    this.encoding = encoding;
  }

  static b2a(b) {
    return base64D.convert(b);
  }

  static a2b(a) {
    return base64E.convert(a);
  }

  static h2a(h) {
    return hex.decode(h);
  }

  static a2h(a) {
    return hex.encode(a);
  }

  // 生成一个256位的密钥，同一个 seed 生成的密钥相同
  static genKey({String seed}) {
    var a = new Digest("SHA-256").process(
        utf8.encode(seed == null ? DateTime.now().toIso8601String() : seed));
    return Cbox.a2b(a);
  }

  encrypt(String plain, {String key, String encoding}) {
    final Uint8List _key = b2a(key != null ? key : this.key);

    var iv = new Digest("SHA-256").process(utf8.encode(plain)).sublist(0, 16);

    CipherParameters params = new PaddedBlockCipherParameters(
        new ParametersWithIV(new KeyParameter(_key), iv), null);
    BlockCipher encryptionCipher = new PaddedBlockCipher("AES/CBC/PKCS7");
    encryptionCipher.init(true, params);

    Uint8List encrypted = encryptionCipher.process(utf8.encode(plain));

    final Uint8List cipherBuf = Uint8List.fromList(iv + encrypted);

    final encoder =
        (encoding != null ? encoding : this.encoding) == 'base64' ? a2b : a2h;
    return encoder(cipherBuf);
  }

  decrypt(String cipher, {String key, String encoding}) {
    final Uint8List _key = b2a(key != null ? key : this.key);

    final decoder =
        (encoding == null ? this.encoding : encoding) == 'base64' ? b2a : h2a;

    final Uint8List cipherBuf = decoder(cipher);

    var iv = cipherBuf.sublist(0, 16);
    var ciphertextBuf = cipherBuf.sublist(16);

    CipherParameters params = new PaddedBlockCipherParameters(
        new ParametersWithIV(new KeyParameter(_key), iv), null);
    BlockCipher decryptionCipher = new PaddedBlockCipher("AES/CBC/PKCS7");
    decryptionCipher.init(false, params);

    String decrypted = utf8.decode(decryptionCipher.process(ciphertextBuf));

    return decrypted;
  }

  encryptBytes(Uint8List bytes, {String key, String encoding}) {
    final Uint8List _key = b2a(key != null ? key : this.key);

    var iv = new Digest("SHA-256").process(bytes).sublist(0, 16);

    CipherParameters params = new PaddedBlockCipherParameters(
        new ParametersWithIV(new KeyParameter(_key), iv), null);
    BlockCipher encryptionCipher = new PaddedBlockCipher("AES/CBC/PKCS7");
    encryptionCipher.init(true, params);

    Uint8List encrypted = encryptionCipher.process(bytes);

    final Uint8List cipherBuf = Uint8List.fromList(iv + encrypted);

    // final encoder =
    //     (encoding != null ? encoding : this.encoding) == 'base64' ? a2b : a2h;
    return cipherBuf;
  }

  decryptBytes(Uint8List bytes, {String key, String encoding}) {
    final Uint8List _key = b2a(key != null ? key : this.key);

    // final decoder =
    // (encoding == null ? this.encoding : encoding) == 'base64' ? b2a : h2a;

    final Uint8List cipherBuf = bytes; //decoder(cipher);

    var iv = cipherBuf.sublist(0, 16);
    var ciphertextBuf = cipherBuf.sublist(16);

    CipherParameters params = new PaddedBlockCipherParameters(
        new ParametersWithIV(new KeyParameter(_key), iv), null);
    BlockCipher decryptionCipher = new PaddedBlockCipher("AES/CBC/PKCS7");
    decryptionCipher.init(false, params);

    // String decrypted = utf8.decode(decryptionCipher.process(ciphertextBuf));

    return decryptionCipher.process(ciphertextBuf);
  }

  Future encryptFile(File src, File dst, {String key, String encoding}) async {
    final Uint8List _key = b2a(key != null ? key : this.key);

    var iv = new Digest("SHA-256")
        .process(utf8.encode(src.absolute.toString()))
        .sublist(0, 16);

    CipherParameters params = new PaddedBlockCipherParameters(
        new ParametersWithIV(new KeyParameter(_key), iv), null);
    BlockCipher encryptionCipher = new PaddedBlockCipher("AES/CBC/PKCS7");
    encryptionCipher.init(true, params);

    var ss = src.openRead();
    IOSink ds = dst.openWrite();

    // 由于 buffer size 为 64k(65536bytes) 而不能修改
    // 且 PKCS7 填充模式会在最末最多填充16个字节
    // 导致每次处理65536字节的时候都会生成65552字节的加密数据，而导致解密的时候出错
    // 因此每次只加密65520字节，而解密的时候正常处理65536字节即可

    // 先将 iv 写入文件
    ds.add(iv);

    List<int> tmp = [];
    Completer c = new Completer();
    ss.listen((e) {
      tmp.addAll(e);
      if (tmp.length >= 65520) {
        ds.add(
          encryptionCipher.process(Uint8List.fromList(tmp.sublist(0, 65520))),
        );
        tmp = tmp.sublist(65520);
      }
    }, onDone: () {
      if (tmp.length > 0) {
        ds.add(encryptionCipher.process(Uint8List.fromList(tmp.sublist(0))));
      }
      ds.close();
      c.complete();
    });
    await c.future;
  }

  Future decryptFile(File enc, File dec, {String key, String encoding}) async {
    final Uint8List _key = b2a(key != null ? key : this.key);

    var ss0 = enc.openRead(0, 16);
    var iv;

    Completer c = new Completer();
    ss0.listen((e) {
      iv = e;
      c.complete();
    });
    await c.future;

    CipherParameters params = new PaddedBlockCipherParameters(
        new ParametersWithIV(new KeyParameter(_key), iv), null);
    BlockCipher decryptionCipher = new PaddedBlockCipher("AES/CBC/PKCS7");
    decryptionCipher.init(false, params);

    var ss = enc.openRead(16);
    IOSink ds = dec.openWrite();

    c = new Completer();
    ss.listen(
      (e) async {
        var bytes = decryptionCipher.process(Uint8List.fromList(e));
        ds.add(bytes);
      },
      onDone: () {
        ds.close();
        c.complete();
      },
    );
    await c.future;
  }
}
