# GlobalAzureDemo2026 - AI Search インデックス作成 & ナレッジデータ投入スクリプト
# azd の postprovision フックから呼び出される (Windows 環境用)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

$IndexName = "sre-knowledge"
$SchemaFile = Join-Path $RepoRoot "data" "ai-search" "index-schema.json"
$DataFile = Join-Path $RepoRoot "data" "ai-search" "knowledge-data.json"

# azd が設定する環境変数から AI Search の情報を取得
$SearchName = $env:AI_SEARCH_NAME
if (-not $SearchName) {
    Write-Host "  ✗ AI_SEARCH_NAME 環境変数が設定されていません" -ForegroundColor Red
    exit 1
}
$SearchEndpoint = "https://${SearchName}.search.windows.net"

$ResourceGroup = $env:AZURE_RESOURCE_GROUP
if (-not $ResourceGroup) {
    Write-Host "  ✗ AZURE_RESOURCE_GROUP 環境変数が設定されていません" -ForegroundColor Red
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " AI Search ナレッジデータ投入" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Search Service: $SearchName"
Write-Host "Endpoint:       $SearchEndpoint"
Write-Host "Index:          $IndexName"
Write-Host ""

# 管理キーを Azure CLI で取得
Write-Host "[1/3] AI Search 管理キーを取得中..." -ForegroundColor Yellow
try {
    $AdminKey = az search admin-key show `
        --service-name $SearchName `
        --resource-group $ResourceGroup `
        --query "primaryKey" -o tsv
    if (-not $AdminKey) {
        throw "管理キーが空です"
    }
    Write-Host "  ✓ 管理キー取得完了" -ForegroundColor Green
} catch {
    Write-Host "  ✗ 管理キーの取得に失敗しました: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

$Headers = @{
    "api-key"      = $AdminKey
    "Content-Type" = "application/json"
}
$ApiVersion = "api-version=2024-07-01"

$ResetAiSearch = $env:RESET_AI_SEARCH -eq "true"

# インデックスを確認 (既存インデックスは保持し、RESET_AI_SEARCH=true の場合のみ削除して再作成)
Write-Host "[2/3] インデックスを確認中..." -ForegroundColor Yellow
if ($ResetAiSearch) {
    Write-Host "  ! RESET_AI_SEARCH=true のため、既存インデックスを再作成します" -ForegroundColor Yellow
}

# 既存インデックスの存在確認
$IndexExists = $false
try {
    $null = Invoke-RestMethod `
        -Uri "$SearchEndpoint/indexes/${IndexName}?${ApiVersion}" `
        -Method Get `
        -Headers $Headers `
        -ErrorAction Stop
    $IndexExists = $true
    Write-Host "  ✓ 既存インデックスを検出" -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "  ✓ 既存インデックスなし (新規作成)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ インデックス存在確認に失敗しました: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

if ($IndexExists -and $ResetAiSearch) {
    try {
        $null = Invoke-RestMethod `
            -Uri "$SearchEndpoint/indexes/${IndexName}?${ApiVersion}" `
            -Method Delete `
            -Headers $Headers `
            -ErrorAction Stop
        Write-Host "  ✓ 既存インデックスをクリーンアップ" -ForegroundColor Green
        $IndexExists = $false
    } catch {
        Write-Host "  ✗ インデックス削除に失敗しました: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} elseif ($IndexExists) {
    Write-Host "  ✓ 既存インデックスを保持します (再作成しません)" -ForegroundColor Green
    Write-Host "    再作成する場合は RESET_AI_SEARCH=true を指定してください" -ForegroundColor Yellow
    Write-Host ""
}

$ShouldCreateIndex = -not $IndexExists
if ($ShouldCreateIndex) {
    try {
        $SchemaBody = Get-Content -Path $SchemaFile -Raw -Encoding UTF8
        $null = Invoke-RestMethod `
            -Uri "$SearchEndpoint/indexes/${IndexName}?${ApiVersion}" `
            -Method Put `
            -Headers $Headers `
            -Body $SchemaBody
        Write-Host "  ✓ インデックス '$IndexName' を作成しました" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ インデックス作成に失敗しました: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# ドキュメントをアップロード
Write-Host "[3/3] ナレッジデータを投入中..." -ForegroundColor Yellow
try {
    $DataBody = Get-Content -Path $DataFile -Raw -Encoding UTF8
    $UploadResult = Invoke-RestMethod `
        -Uri "$SearchEndpoint/indexes/${IndexName}/docs/index?${ApiVersion}" `
        -Method Post `
        -Headers $Headers `
        -Body $DataBody

    # 個別ドキュメントの失敗チェック
    $FailedDocs = @($UploadResult.value | Where-Object { $_.status -eq $false })
    if ($FailedDocs.Count -gt 0) {
        Write-Host "  ✗ $($FailedDocs.Count) 件のドキュメント投入に失敗しました" -ForegroundColor Red
        $FailedDocs | ForEach-Object {
            Write-Host "    Key: $($_.key), Error: $($_.errorMessage)" -ForegroundColor Red
        }
        exit 1
    }
    Write-Host "  ✓ ナレッジデータの投入が完了しました" -ForegroundColor Green
} catch {
    Write-Host "  ✗ データ投入に失敗しました: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " 完了" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "AI Search エンドポイント: $SearchEndpoint"
Write-Host "インデックス名:          $IndexName"
Write-Host ""
Write-Host "検索テスト例:" -ForegroundColor Yellow
Write-Host "  Invoke-RestMethod ``" -ForegroundColor Cyan
Write-Host "    -Uri '$SearchEndpoint/indexes/$IndexName/docs/search?$ApiVersion' ``" -ForegroundColor Cyan
Write-Host "    -Method Post ``" -ForegroundColor Cyan
Write-Host "    -Headers @{ 'api-key' = '<QUERY_KEY>'; 'Content-Type' = 'application/json' } ``" -ForegroundColor Cyan
Write-Host "    -Body '{`"search`": `"premium 検索 遅延`"}'" -ForegroundColor Cyan
