# J Harness Windows x64 빠른 시작

1. 압축을 푼 폴더에서 `.\Install-JHarness.cmd -ProjectPath "C:\Projects\MyProject" -ApproveInstall`을 실행하세요. 경로는 작업할 프로젝트 폴더로 바꾸세요. 압축을 푼 폴더에서 그대로 작업하려면 `.\JHarness.cmd setup`을 실행하세요.
2. 프로젝트 폴더에서 PowerShell을 열고 `.\JHarness.cmd quickstart`를 실행하세요. 실행 파일을 찾은 AI CLI부터 표시됩니다. 목록에 나온 선택 명령 중 하나를 실행하세요. 예를 들어 Codex는 `.\JHarness.cmd select codex`로 선택합니다. 처음 고른 CLI는 해당 프로젝트에 저장됩니다.
3. Claude Code 연결 안내가 나오면 `.\JHarness.cmd connect claude`를 실행하세요. 같은 폴더에서 선택한 CLI를 시작하고 만들고 싶은 프로그램을 설명하세요. 하네스가 환경 확인, 구현, 테스트, 실행법 안내까지 진행하도록 요청하세요.

패키지에는 Node가 포함됩니다. 설치에는 Windows PowerShell 5.1 이상과 작업 폴더 쓰기 권한이 필요합니다. `.\JHarness.cmd doctor`로 설치를 확인할 수 있습니다. 기존 지침과 작업 기록은 설치기가 보존합니다.

Alpha 3, 8.1.0, 8.2.0 또는 8.2.1에서 업데이트하거나 중단된 업데이트를 복구하려면 [패키지 사용 안내](.agents/j-harness/PORTABLE.md)를 따르세요.
