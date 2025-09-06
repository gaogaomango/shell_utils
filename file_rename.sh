#!/bin/bash

# ファイル・ディレクトリ名にPrefixを追加するShellスクリプト
# 使用方法: ./add_prefix.sh [オプション] <prefix> <ディレクトリ>

# デフォルト設定
DIRECTORY="."
PREFIX=""
DRY_RUN=false
BACKUP=false
EXTENSION=""
VERBOSE=false

# ヘルプメッセージ
show_help() {
    echo "使用方法: $0 [オプション] <prefix> [ディレクトリ]"
    echo ""
    echo "オプション:"
    echo "  -h, --help              このヘルプメッセージを表示"
    echo "  -d, --dry-run           実際にはリネームせず、プレビューのみ表示"
    echo "  -b, --backup            リネーム前にバックアップを作成"
    echo "  -e, --extension EXT     指定した拡張子のファイルのみ処理（ディレクトリは除外）"
    echo "  -v, --verbose           詳細な出力を表示"
    echo ""
    echo "例:"
    echo "  $0 \"new_\" .                    # 現在のディレクトリの全ファイル・ディレクトリに\"new_\"を追加"
    echo "  $0 \"backup_\" /path/to/files    # 指定ディレクトリの全ファイル・ディレクトリに\"backup_\"を追加"
    echo "  $0 -e \".txt\" \"doc_\" .         # .txtファイルのみに\"doc_\"を追加（ディレクトリは除外）"
    echo "  $0 -d \"test_\" .                # プレビューのみ表示"
    echo "  $0 -b \"backup_\" .              # バックアップを作成してからリネーム"
}

# ログ関数
log() {
    if [ "$VERBOSE" = true ]; then
        echo "[INFO] $1"
    fi
}

# エラーメッセージ
error() {
    echo "[ERROR] $1" >&2
}

# 引数の解析
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -b|--backup)
                BACKUP=true
                shift
                ;;
            -e|--extension)
                EXTENSION="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -*)
                error "不明なオプション: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$PREFIX" ]; then
                    PREFIX="$1"
                elif [ -z "$DIRECTORY" ] || [ "$DIRECTORY" = "." ]; then
                    DIRECTORY="$1"
                else
                    error "引数が多すぎます: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
}

# 引数チェック
validate_arguments() {
    if [ -z "$PREFIX" ]; then
        error "Prefixが指定されていません"
        show_help
        exit 1
    fi

    if [ ! -d "$DIRECTORY" ]; then
        error "ディレクトリが存在しません: $DIRECTORY"
        exit 1
    fi
}

# ファイルとディレクトリの検索とフィルタリング
find_items() {
    if [ -n "$EXTENSION" ]; then
        # 拡張子でフィルタリング（ファイルのみ）
        find "$DIRECTORY" -maxdepth 1 -type f -name "*$EXTENSION" | grep -v "^$DIRECTORY$"
    else
        # 全ファイルとディレクトリ
        find "$DIRECTORY" -maxdepth 1 \( -type f -o -type d \) | grep -v "^$DIRECTORY$"
    fi
}

# バックアップの作成
create_backup() {
    local file="$1"
    local backup_file="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if cp "$file" "$backup_file"; then
        log "バックアップを作成しました: $backup_file"
        return 0
    else
        error "バックアップの作成に失敗しました: $file"
        return 1
    fi
}

# ファイルのリネーム
rename_file() {
    local file="$1"
    local dir=$(dirname "$file")
    local filename=$(basename "$file")
    local new_name="${PREFIX}${filename}"
    local new_path="${dir}/${new_name}"
    
    # 既に同じ名前のファイルが存在するかチェック
    if [ -e "$new_path" ]; then
        error "既に同じ名前のファイルが存在します: $new_path"
        return 1
    fi
    
    # バックアップが必要な場合
    if [ "$BACKUP" = true ]; then
        if ! create_backup "$file"; then
            return 1
        fi
    fi
    
    # 実際のリネーム
    if mv "$file" "$new_path"; then
        echo "✓ [ファイル] $filename → $new_name"
        return 0
    else
        error "リネームに失敗しました: $file"
        return 1
    fi
}

# ディレクトリのリネーム
rename_directory() {
    local dir_path="$1"
    local parent_dir=$(dirname "$dir_path")
    local dirname=$(basename "$dir_path")
    local new_name="${PREFIX}${dirname}"
    local new_path="${parent_dir}/${new_name}"
    
    # 既に同じ名前のディレクトリが存在するかチェック
    if [ -e "$new_path" ]; then
        error "既に同じ名前のディレクトリが存在します: $new_path"
        return 1
    fi
    
    # バックアップが必要な場合（ディレクトリの場合は再帰的にコピー）
    if [ "$BACKUP" = true ]; then
        local backup_dir="${dir_path}.backup.$(date +%Y%m%d_%H%M%S)"
        if cp -r "$dir_path" "$backup_dir"; then
            log "ディレクトリのバックアップを作成しました: $backup_dir"
        else
            error "ディレクトリのバックアップの作成に失敗しました: $dir_path"
            return 1
        fi
    fi
    
    # 実際のリネーム
    if mv "$dir_path" "$new_path"; then
        echo "✓ [ディレクトリ] $dirname → $new_name"
        return 0
    else
        error "ディレクトリのリネームに失敗しました: $dir_path"
        return 1
    fi
}

# プレビュー表示
preview_rename() {
    local item="$1"
    local dir=$(dirname "$item")
    local name=$(basename "$item")
    local new_name="${PREFIX}${name}"
    local new_path="${dir}/${new_name}"
    
    # ファイルかディレクトリかを判定
    local item_type=""
    if [ -d "$item" ]; then
        item_type="[ディレクトリ]"
    else
        item_type="[ファイル]"
    fi
    
    if [ -e "$new_path" ]; then
        echo "⚠ $item_type $name → $new_name (既存と競合)"
        return 1
    else
        echo "  $item_type $name → $new_name"
        return 0
    fi
}

# メイン処理
main() {
    parse_arguments "$@"
    validate_arguments
    
    log "Prefix: $PREFIX"
    log "ディレクトリ: $DIRECTORY"
    log "拡張子フィルタ: ${EXTENSION:-"なし"}"
    log "ドライラン: $DRY_RUN"
    log "バックアップ: $BACKUP"
    
    # ファイル・ディレクトリ一覧を取得
    items=()
    while IFS= read -r item; do
        items+=("$item")
    done < <(find_items)
    
    if [ ${#items[@]} -eq 0 ]; then
        echo "処理対象のファイル・ディレクトリが見つかりませんでした。"
        exit 0
    fi
    
    echo "処理対象数: ${#items[@]}"
    echo ""
    
    # プレビューまたは実際の処理
    if [ "$DRY_RUN" = true ]; then
        echo "=== プレビュー ==="
        local conflict_count=0
        for item in "${items[@]}"; do
            if ! preview_rename "$item"; then
                ((conflict_count++))
            fi
        done
        
        if [ $conflict_count -gt 0 ]; then
            echo ""
            echo "⚠ $conflict_count 個のアイテムで競合が発生します。"
        fi
    else
        echo "=== リネーム実行 ==="
        local success_count=0
        local error_count=0
        
        for item in "${items[@]}"; do
            if [ -d "$item" ]; then
                # ディレクトリの場合
                if rename_directory "$item"; then
                    ((success_count++))
                else
                    ((error_count++))
                fi
            else
                # ファイルの場合
                if rename_file "$item"; then
                    ((success_count++))
                else
                    ((error_count++))
                fi
            fi
        done
        
        echo ""
        echo "処理完了: 成功 $success_count 件, エラー $error_count 件"
    fi
}

# スクリプト実行
main "$@"