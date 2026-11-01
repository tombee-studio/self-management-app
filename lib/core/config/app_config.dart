/// アプリ全体の設定・本番構成定数
class AppConfig {
  /// AWS API Gateway (HTTP API v2) 事前デプロイ済み本番エンドポイント
  static const String defaultCloudSyncEndpoint = String.fromEnvironment(
    'IRIS_API_ENDPOINT',
    defaultValue: 'https://tidcbcu3f9.execute-api.ap-northeast-1.amazonaws.com',
  );

  /// 単一ユーザー運用時の固定ユーザーID（AWS DynamoDBパーティションキー）
  static const String defaultUserId = String.fromEnvironment(
    'IRIS_OWNER_ID',
    defaultValue: '028692f2-c4c5-4299-9eb0-0ae7ed02049c',
  );
}
