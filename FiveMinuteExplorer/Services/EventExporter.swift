import Foundation

enum EventExporter {
  static func write(
    records: [QuestEventRecord],
    catalogVersion: String,
    recommendationVersion: String,
    now: Date = Date(),
    directory: URL? = nil
  ) throws -> URL {
    let envelope = QuestEventExportEnvelope(
      schemaVersion: "v0.2",
      appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        ?? "unknown",
      buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        ?? "unknown",
      catalogVersion: catalogVersion,
      recommendationVersion: recommendationVersion,
      exportedAt: now,
      events: records.map { QuestEventExport($0) }
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(envelope)

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let fileName = "FiveMinuteExplorer-events-\(formatter.string(from: now)).json"
    let url = (directory ?? FileManager.default.temporaryDirectory).appendingPathComponent(fileName)
    try data.write(to: url, options: .atomic)
    return url
  }
}
