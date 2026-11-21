# J Harness Windows x64 빠른 시작

1. 압축을 푼 폴더에서 `.\Install-JHarness.cmd -ProjectPath "C:\Projects\MyProject" -ApproveInstall`을 실행하세요. 경로는 작업할 프로젝트 폴더로 바꾸세요. 압축을 푼 폴더에서 그대로 작업하려면 `.\JHarness.cmd setup`을 실행하세요.
2. 프로젝트 폴더에서 PowerShell을 열고 `.\JHarness.cmd quickstart`를 실행하세요. 사용할 CLI의 설치 안내나 첫 요청 예시가 나옵니다. CLI를 고르려면 `--client codex`, `--client claude`, `--client agy` 중 하나를 붙이세요.
3. 같은 폴더에서 선택한 CLI를 시작하고 만들고 싶은 프로그램을 설명하세요. 하네스가 환경 확인, 구현, 테스트, 실행법 안내까지 진행하도록 요청하세요.

패키지에는 Node가 포함됩니다. 설치에는 Windows PowerShell 5.1 이상과 작업 폴더 쓰기 권한이 필요합니다. `.\JHarness.cmd doctor`로 설치를 확인할 수 있습니다. 기존 지침과 작업 기록은 설치기가 보존합니다.

Alpha 3에서 업데이트하거나 중단된 업데이트를 복구하려면 [패키지 사용 안내](.agents/j-harness/PORTABLE.md)를 따르세요.
