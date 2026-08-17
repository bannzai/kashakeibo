import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashakeibo/provider/account.dart';
import 'package:mocktail/mocktail.dart';

/// テスト用 Firebase Auth モック。
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

/// テスト用 Firebase ユーザーモック。
class MockUser extends Mock implements User {}

/// アカウント削除機能のテスト。
void main() {
  test('アカウント削除は再認証後に全明細・ユーザードキュメント・Authを削除する', () async {
    final firebaseFirestore = FakeFirebaseFirestore();
    final firebaseAuth = MockFirebaseAuth();
    final firebaseUser = MockUser();
    var reauthenticationCount = 0;
    var imageDeletionCount = 0;
    var currentUserReadCount = 0;
    when(
      () => firebaseAuth.currentUser,
    ).thenAnswer((_) => currentUserReadCount++ == 0 ? firebaseUser : null);
    when(() => firebaseUser.uid).thenReturn('user-id');
    when(() => firebaseUser.delete()).thenAnswer((_) async {});

    await firebaseFirestore.collection('users').doc('user-id').set({
      'created': true,
    });
    final seedBatch = firebaseFirestore.batch();
    // 削除処理が400件のページ境界を越えても全件削除することを確認するため401件作る。
    for (var index = 0; index < 401; index++) {
      seedBatch.set(
        firebaseFirestore
            .collection('users')
            .doc('user-id')
            .collection('transactions')
            .doc('transaction-$index'),
        {'index': index},
      );
    }
    await seedBatch.commit();

    final deleteAccount = FirebaseDeleteAccount(
      firebaseAuth: firebaseAuth,
      firebaseFirestore: firebaseFirestore,
      reauthenticateForAccountDeletion: ({required user}) async {
        reauthenticationCount++;
        return null;
      },
      deleteAllImagesForAccount: ({required user}) async {
        imageDeletionCount++;
      },
    );
    await deleteAccount.call();
    // 削除済み状態で再実行しても何も起こらない。
    await deleteAccount.call();

    expect(reauthenticationCount, 1);
    expect(imageDeletionCount, 1);
    expect(
      (await firebaseFirestore
              .collection('users')
              .doc('user-id')
              .collection('transactions')
              .get())
          .docs,
      isEmpty,
    );
    expect(
      (await firebaseFirestore.collection('users').doc('user-id').get()).exists,
      isFalse,
    );
    verify(() => firebaseUser.delete()).called(1);
    verifyNever(() => firebaseAuth.revokeTokenWithAuthorizationCode(any()));
  });

  test('Appleの認可コードがある場合はトークンを失効してからアカウントを削除する', () async {
    final firebaseAuth = MockFirebaseAuth();
    final firebaseUser = MockUser();
    when(() => firebaseAuth.currentUser).thenReturn(firebaseUser);
    when(() => firebaseUser.uid).thenReturn('user-id');
    when(
      () => firebaseAuth.revokeTokenWithAuthorizationCode('authorization-code'),
    ).thenAnswer((_) async {});
    when(() => firebaseUser.delete()).thenAnswer((_) async {});

    await FirebaseDeleteAccount(
      firebaseAuth: firebaseAuth,
      firebaseFirestore: FakeFirebaseFirestore(),
      reauthenticateForAccountDeletion: ({required user}) async =>
          'authorization-code',
      deleteAllImagesForAccount: ({required user}) async {},
    ).call();

    verifyInOrder([
      () => firebaseAuth.revokeTokenWithAuthorizationCode('authorization-code'),
      () => firebaseUser.delete(),
    ]);
  });

  test('再認証が失敗した場合は保存済みデータを削除しない', () async {
    final firebaseFirestore = FakeFirebaseFirestore();
    final firebaseAuth = MockFirebaseAuth();
    final firebaseUser = MockUser();
    when(() => firebaseAuth.currentUser).thenReturn(firebaseUser);
    when(() => firebaseUser.uid).thenReturn('user-id');
    await firebaseFirestore.collection('users').doc('user-id').set({
      'created': true,
    });

    await expectLater(
      FirebaseDeleteAccount(
        firebaseAuth: firebaseAuth,
        firebaseFirestore: firebaseFirestore,
        reauthenticateForAccountDeletion: ({required user}) async =>
            throw FirebaseAuthException(code: 'requires-recent-login'),
        deleteAllImagesForAccount: ({required user}) async {},
      ).call(),
      throwsA(isA<FirebaseAuthException>()),
    );

    expect(
      (await firebaseFirestore.collection('users').doc('user-id').get()).exists,
      isTrue,
    );
    verifyNever(() => firebaseUser.delete());
  });

  test('R2画像の削除が失敗した場合はFirestoreとAuthを削除しない', () async {
    final firebaseFirestore = FakeFirebaseFirestore();
    final firebaseAuth = MockFirebaseAuth();
    final firebaseUser = MockUser();
    when(() => firebaseAuth.currentUser).thenReturn(firebaseUser);
    when(() => firebaseUser.uid).thenReturn('user-id');
    await firebaseFirestore.collection('users').doc('user-id').set({
      'created': true,
    });

    await expectLater(
      FirebaseDeleteAccount(
        firebaseAuth: firebaseAuth,
        firebaseFirestore: firebaseFirestore,
        reauthenticateForAccountDeletion: ({required user}) async => null,
        deleteAllImagesForAccount: ({required user}) async =>
            throw StateError('画像削除失敗'),
      ).call(),
      throwsStateError,
    );

    expect(
      (await firebaseFirestore.collection('users').doc('user-id').get()).exists,
      isTrue,
    );
    verifyNever(() => firebaseUser.delete());
  });
}
