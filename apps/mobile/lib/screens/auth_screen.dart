/// 로그인 화면. iOS `Drop/AuthView.swift` 대응.
///
/// 화면에 있는 것은 셋뿐이다 — 이름, 한 줄, 버튼. 설명을 더 붙일수록 "던져넣기"의
/// 가벼움이 사라진다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../environment/providers.dart';
import '../theme/drop_theme.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final colors = DropColors.of(context);
    final isWorking = auth.state is AuthWorking;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DropLayout.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 3),
              Text(
                'DROP',
                style: DropText.wordmark.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: DropTokenSpace.x3),
              Text(
                '떠오르면 바로 던져넣기',
                style: DropText.cardTitle.copyWith(color: colors.textSecondary),
              ),
              const Spacer(flex: 4),
              if (auth.state case AuthFailed(:final message))
                Padding(
                  padding: const EdgeInsets.only(bottom: DropTokenSpace.x4),
                  child: Text(
                    message,
                    style: DropText.body.copyWith(color: colors.danger),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: DropLayout.controlHeight,
                child: FilledButton(
                  onPressed: isWorking
                      ? null
                      : () =>
                            ref.read(authControllerProvider).signInWithGoogle(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isWorking) ...[
                        const SizedBox(
                          width: DropTokenSpace.x4,
                          height: DropTokenSpace.x4,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: DropTokenSpace.x3),
                      ],
                      const Text('Google로 계속하기'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DropTokenSpace.x5),
            ],
          ),
        ),
      ),
    );
  }
}
