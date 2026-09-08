import Foundation

enum EventExporter {
  static func write(
    records: [QuestEventRecord],
    catalogVersion: String,
    now: Date = Date()
  ) throws -> URL {
    let envelope = QuestEventExportEnvelope(
      schemaVersion: "v0.1",
      catalogVersion: catalogVersion,
      exportedAt: now,
      events: records.map(QuestEventExport.init)
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(envelope)

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let fileName = "FiveMinuteExplorer-events-\(formatter.string(from: now)).json"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    try data.write(to: url, options: .atomic)
    return url
  }
}
