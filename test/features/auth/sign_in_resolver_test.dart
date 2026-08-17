import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kashakeibo/features/auth/sign_in_resolver.dart';
import 'package:kashakeibo/provider/firebase_user.dart';
import 'package:mocktail/mocktail.dart';

/// SignInResolver テスト用 Firebase ユーザーモック。
class MockResolverUser extends Mock implements User {}

/// SignInResolver の匿名認証復帰を検証する。
void main() {
  testWidgets('アカウント削除でユーザーがnullへ戻ると匿名認証を再実行する', (tester) async {
    final firebaseUserController = StreamController<User?>();
    final firebaseUser = MockResolverUser();
    var anonymousSignInCount = 0;
    when(() => firebaseUser.uid).thenReturn('linked-user-id');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseUserChangesProvider.overrideWith(
            (ref) => firebaseUserController.stream,
          ),
          ensureAnonymousSignInProvider.overrideWithValue(() async {
            anonymousSignInCount++;
          }),
        ],
        child: const MaterialApp(home: SignInResolver(child: Text('サインイン済み'))),
      ),
    );
    await tester.pump();
    expect(anonymousSignInCount, 1);

    firebaseUserController.add(firebaseUser);
    await tester.pumpAndSettle();
    expect(find.text('サインイン済み'), findsOneWidget);

    firebaseUserController.add(null);
    await tester.pump();
    await tester.pump();
    expect(anonymousSignInCount, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await firebaseUserController.close();
  });
}
