library sembast.io_file_system_test;

// basically same as the io runner but with extra output
//import 'package:tekartik_test/test_config.dart';
import 'package:sembast/src/file_system.dart';
import 'dart:async';
import 'package:path/path.dart';
import 'dart:convert';
import 'test_common.dart';

main() {
  group('memory', () {
    defineTests(memoryFileSystemContext);
  });
}

void defineTests(FileSystemTestContext ctx) {
  FileSystem fs = ctx.fs;
  /*
  TODO

  String outDataPath = testOutPath(fs);
*/

  String namePath(String name) => join(ctx.outPath, name);

  File nameFile(String name) => fs.newFile(namePath(name));
  Directory nameDir(String name) => fs.newDirectory(namePath(name));

  Future<File> createFile(File file) async {
    File file_ = await file.create(recursive: true);
    expect(file, file_); // identical
    return file_;
  }

  Future<File> createFileName(String name) => createFile(nameFile(name));

  Future expectDirExists(Directory dir, [bool exists = true]) async {
    bool exists_ = await dir.exists();
    expect(exists_, exists);
  }

  Future expectFileExists(File file, [bool exists = true]) async {
    bool exists_ = await file.exists();
    expect(exists_, exists);
  }

  Future expectFileNameExists(String name, [bool exists = true]) =>
      expectFileExists(nameFile(name), exists);

  Stream<List<int>> openRead(File file) {
    return file.openRead();
  }

  Stream<String> openReadLines(File file) {
    return openRead(file).transform(UTF8.decoder).transform(new LineSplitter());
  }

  IOSink openWrite(File file) {
    return file.openWrite(mode: FileMode.WRITE);
  }

  IOSink openAppend(File file) {
    return file.openWrite(mode: FileMode.APPEND);
  }

  Future<File> deleteFile(File file) {
    return (file.delete(recursive: true) as Future<File>).then((File file_) {
      expect(file, file_);
      return file_;
    });
  }

  Future<Directory> deleteDirectory(Directory dir) {
    return (dir.delete(recursive: true) as Future<Directory>)
        .then((Directory dir_) {
      expect(dir, dir_);
      return dir_;
    });
  }

  Future clearOutFolder() async {
    await deleteDirectory(fs.newDirectory(ctx.outPath))
        .catchError((FileSystemException e, st) {
      //devPrint("${e}\n${st}");
    });
  }

  Future<List<String>> readContent(File file) {
    List<String> content = [];
    return openReadLines(file).listen((String line) {
      content.add(line);
    }).asFuture(content);
  }

  Future writeContent(File file, List<String> content) {
    IOSink sink = openWrite(file);
    content.forEach((String line) {
      sink.writeln(line);
    });
    return sink.close();
  }

  Future appendContent(File file, List<String> content) {
    IOSink sink = openAppend(file);
    content.forEach((String line) {
      sink.writeln(line);
    });
    return sink.close();
  }

  setUp(() {
    // return clearOutFolder();
  });

  tearDown(() {});

  group('fs', () {
    group('file_system', () {
      test('currentDirectory', () {
        expect(fs.currentDirectory, isNotNull);
      });

      test('scriptFile', () {
        //expect(fs.scriptFile, isNotNull);
      });

      test('type', () async {
        await clearOutFolder();
        return fs.type(namePath("test")).then((FileSystemEntityType type) {
          expect(type, FileSystemEntityType.NOT_FOUND);
        }).then((_) {
          return fs.isFile(namePath("test")).then((bool isFile) {
            expect(isFile, false);
          });
        }).then((_) {
          return fs.isDirectory(namePath("test")).then((bool isFile) {
            expect(isFile, false);
          });
        });
      });
    });

    group('dir', () {
      test('new', () {
        Directory dir = fs.newDirectory("dummy");
        expect(dir.path, "dummy");
        dir = fs.newDirectory(r"\root/dummy");
        expect(dir.path, r"\root/dummy");
        dir = fs.newDirectory(r"\");
        expect(dir.path, r"\");
        dir = fs.newDirectory(r"");
        expect(dir.path, r"");
        try {
          dir = fs.newDirectory(null);
          fail("should fail");
        } on ArgumentError catch (_) {
          // Invalid argument(s): null is not a String
        }
      });
      test('dir exists', () async {
        await clearOutFolder();
        await expectDirExists(nameDir("test"), false);
      });

      test('dir create', () async {
        await clearOutFolder();
        Directory dir = nameDir("test");
        Directory dir2 = nameDir("test");
        expect(await fs.isDirectory(dir.path), isFalse);
        await dir.create(recursive: true);
        await expectDirExists(dir, true);
        await expectDirExists(dir2, true);
        expect(await fs.isDirectory(dir.path), isTrue);

        // create another object
        dir = nameDir("test");
        await expectDirExists(dir, true);

        // second time fine too
        await dir.create(recursive: true);
      });

      test('fileSystem', () {
        Directory dir = nameDir("test");
        expect(dir.fileSystem, fs);
      });

      test('sub dir create', () async {
        await clearOutFolder();
        Directory mainDir = nameDir("test");
        Directory subDir = fs.newDirectory(join(mainDir.path, "test"));

        return subDir.create(recursive: true).then((_) {
          return expectDirExists(mainDir, true).then((_) {});
        });
      });

      test('dir delete', () async {
        await clearOutFolder();
        Directory dir = nameDir("test");

        try {
          await dir.delete(recursive: true);
          fail("shoud fail");
        } on FileSystemException catch (_) {
          // FileSystemException: Deletion failed, path = '/media/ssd/devx/git/sembast.dart/test/out/io/fs/dir/dir delete/test' (OS Error: No such file or directory, errno = 2)
          // FileSystemException: Deletion failed, path = 'current/test' (OS Error: No such file or directory, errno = 2)
        }

        await expectDirExists(dir, false);

        await dir.create(recursive: true);
        await expectDirExists(dir, true);
        await dir.delete(recursive: true);
        await expectDirExists(dir, false);
      });

      test('sub dir delete', () async {
        await clearOutFolder();
        Directory mainDir = nameDir("test");
        Directory subDir = fs.newDirectory(join(mainDir.path, "test"));

        // not recursive
        await subDir.create(recursive: true);

        try {
          await mainDir.delete();
          fail("shoud fail");
        } on FileSystemException catch (_) {
          // FileSystemException: Deletion failed, path = '/media/ssd/devx/git/sembast.dart/test/out/io/fs/dir/sub dir delete/test' (OS Error: Directory not empty, errno = 39)
          // FileSystemException: Deletion failed, path = 'current/test' (OS Error: Directory is not empty, errno = 39)
        }
        await expectDirExists(mainDir, true);
        await mainDir.delete(recursive: true);
        await expectDirExists(mainDir, false);
      });
    });
    group('file', () {
      test('new', () {
        File file = fs.newFile("dummy");
        expect(file.path, "dummy");
        file = fs.newFile(r"\root/dummy");
        expect(file.path, r"\root/dummy");
        file = fs.newFile(r"\");
        expect(file.path, r"\");
        file = fs.newFile(r"");
        expect(file.path, r"");
        try {
          file = fs.newFile(null);
          fail("should fail");
        } on ArgumentError catch (_) {
          // Invalid argument(s): null is not a String
        }
      });
      test('file exists', () async {
        await clearOutFolder();
        return expectFileNameExists("test", false);
      });

      test('file create', () async {
        await clearOutFolder();
        File file = nameFile("test");
        expect(await file.exists(), isFalse);
        expect(await fs.isFile(file.path), isFalse);
        File createdFile = await createFile(file);
        expect(await fs.isFile(file.path), isTrue);
        expect(await createdFile.exists(), isTrue);
        expect(await file.exists(), isTrue);

        // create twice ok
        File createdFile2 = await createFile(file);
        expect(await createdFile2.exists(), isTrue);
      });

      test('file delete', () async {
        await clearOutFolder();
        File file = nameFile("test");

        try {
          await deleteFile(file);
          fail('should fail');
        } on FileSystemException catch (_) {
          // FileSystemException: Deletion failed, path = '/media/ssd/devx/git/sembast.dart/test/out/io/fs/file/file delete/test' (OS Error: No such file or directory, errno = 2)
          // FileSystemException: Deletion failed, path = 'current/test' (OS Error: No such file or directory, errno = 2)
        }
        await expectFileExists(file, false);
        await createFile(file);
        await expectFileExists(file, true);
        await deleteFile(file);
        await expectFileExists(file, false);
      });

      test('file delete 2', () async {
        await clearOutFolder();
        File file = nameFile(join("sub", "test"));

        try {
          await deleteFile(file);
          fail('should fail');
        } on FileSystemException catch (_) {
          // FileSystemException: Deletion failed, path = '/media/ssd/devx/git/sembast.dart/test/out/io/fs/file/file delete/test' (OS Error: No such file or directory, errno = 2)
          // FileSystemException: Deletion failed, path = 'current/test' (OS Error: No such file or directory, errno = 2)
        }
        await expectFileExists(file, false);
        await createFile(file);
        await expectFileExists(file, true);
        await deleteFile(file);
        await expectFileExists(file, false);
      });

      test('open read 1', () async {
        await clearOutFolder();
        File file = nameFile("test");
        var e;
        await openRead(file)
            .listen((_) {}, onError: (_) {
              print(_);
            })
            .asFuture()
            .catchError((e_) {
              // FileSystemException: Cannot open file, path = '/media/ssd/devx/git/sembast.dart/test/out/io/fs/file/open read 1/test' (OS Error: No such file or directory, errno = 2)
              // FileSystemException: Cannot open file, path = 'current/test' (OS Error: No such file or directory, errno = 2)
              e = e_;
            });
        expect(e, isNotNull);
      });

      test('open write 1', () async {
        await clearOutFolder();
        File file = nameFile("test");
        IOSink sink = openWrite(file);
        //sink.writeln("test");
        try {
          await sink.close();
          fail('should fail');
        } on FileSystemException catch (_) {
          // FileSystemException: Cannot open file, path = '/media/ssd/devx/git/sembast.dart/test/out/io/fs/file/open write 1/test' (OS Error: No such file or directory, errno = 2)
          // FileSystemException: Cannot open file, path = 'current/test' (OS Error: No such file or directory, errno = 2)
        }
        ;
      });

      test('open write 2', () async {
        await clearOutFolder();
        return createFileName("test").then((File file) {
          IOSink sink = openWrite(file);
          sink.writeln("test");
          return sink.close().then((_) {
            return readContent(file).then((List<String> content) {
              expect(content, ["test"]);
            });
          });
        });
      });

      test('open write 3', () async {
        await clearOutFolder();
        return createFileName("test").then((File file) {
          return writeContent(file, ["test1"]).then((_) {
            // override existing
            return writeContent(file, ["test2"]).then((_) {
              return readContent(file).then((List<String> content) {
                expect(content, ["test2"]);
              });
            });
          });
        });
      });

      test('open append 1', () async {
        await clearOutFolder();
        File file = nameFile("test");
        IOSink sink = openAppend(file);
        //sink.writeln("test");
        try {
          await sink.close();
          fail('should fail');
        } on FileSystemException catch (_) {
          // FileSystemException: Cannot open file, path = '/media/ssd/devx/git/sembast.dart/test/out/io/fs/file/open write 1/test' (OS Error: No such file or directory, errno = 2)
          // FileSystemException: Cannot open file, path = 'current/test' (OS Error: No such file or directory, errno = 2)
        }
        ;
      });

      test('open append 2', () async {
        await clearOutFolder();
        return createFileName("test").then((File file) {
          IOSink sink = openAppend(file);
          sink.writeln("test");
          return sink.close().then((_) {
            return readContent(file).then((List<String> content) {
              expect(content, ["test"]);
            });
          });
        });
      });

      test('open append 3', () async {
        await clearOutFolder();
        return createFileName("test").then((File file) {
          return writeContent(file, ["test1"]).then((_) {
            return appendContent(file, ["test2"]).then((_) {
              return readContent(file).then((List<String> content) {
                expect(content, ["test1", "test2"]);
              });
            });
          });
        });
      });

      test('rename', () async {
        await clearOutFolder();
        return createFileName("test").then((File file) {
          return file.rename(namePath("test2")).then((File renamed) {
            return expectFileExists(renamed).then((_) {
              return expectFileExists(file, false).then((_) {});
            });
          });
        });
      });

      test('rename to existing', () async {
        await clearOutFolder();
        return createFileName("test").then((File file) {
          String path2 = namePath("test2");
          return createFile(fs.newFile(path2)).then((_) {
            return file.rename(path2).then((File renamed) {
              //devPrint(renamed);
            }).catchError((e) {
              //devPrint(e);
            });
          });
        });
      });

      test('rename and read', () async {
        await clearOutFolder();
        File file = await createFileName("test");
        await writeContent(file, ["test1"]);
        String path2 = namePath("test2");
        File file2 = await file.rename(path2);
        List<String> content = await readContent(file2);
        expect(content, ["test1"]);
      });

      test('create_write_then_create', () async {
        await clearOutFolder();
        File file = nameFile("test");
        file = await createFile(file);
        IOSink sink = openWrite(file);
        sink.writeln("test");
        await sink.close();

        // create again
        file = await createFile(file);
        List<String> lines = [];
        await openReadLines(file).listen((String line) {
          lines.add(line);
        }).asFuture();
        expect(lines, ['test']);
      });

      test('depp_create_write_then_create', () async {
        await clearOutFolder();
        File file = nameFile(join("test", "sub", "yet another"));
        file = await createFile(file);
        IOSink sink = openWrite(file);
        sink.writeln("test");
        await sink.close();

        // create again
        file = await createFile(file);
        List<String> lines = [];

        file = nameFile(join("test", "sub", "yet another"));
        await openReadLines(file).listen((String line) {
          lines.add(line);
        }).asFuture();
        expect(lines, ['test']);
      });
    });
  });
}
