class MangaSearchModel {
  final String id;
  final String type;
  final MangaAttributes attributes;
  final List<MangaRelationship> relationships;

  MangaSearchModel({
    required this.id,
    required this.type,
    required this.attributes,
    required this.relationships,
  });

  factory MangaSearchModel.fromJson(Map<String, dynamic> json) {
    return MangaSearchModel(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      attributes: MangaAttributes.fromJson(json['attributes']),
      relationships: (json['relationships'] as List<dynamic>?)
              ?.map((e) => MangaRelationship.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class MangaAttributes {
  final Map<String, String> title;
  final List<Map<String, String>> altTitles;
  final Map<String, String> description;
  final bool isLocked;
  final Map<String, dynamic> links;
  final String originalLanguage;
  final String lastVolume;
  final String lastChapter;
  final String publicationDemographic;
  final String status;
  final int? year;
  final String contentRating;
  final List<MangaTag> tags;
  final String state;
  final bool chapterNumbersResetOnNewVolume;
  final String createdAt;
  final String updatedAt;
  final int version;
  final List<String> availableTranslatedLanguages;
  final String? latestUploadedChapter;

  MangaAttributes({
    required this.title,
    required this.altTitles,
    required this.description,
    required this.isLocked,
    required this.links,
    required this.originalLanguage,
    required this.lastVolume,
    required this.lastChapter,
    required this.publicationDemographic,
    required this.status,
    required this.year,
    required this.contentRating,
    required this.tags,
    required this.state,
    required this.chapterNumbersResetOnNewVolume,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.availableTranslatedLanguages,
    required this.latestUploadedChapter,
  });

  factory MangaAttributes.fromJson(Map<String, dynamic> json) {
    return MangaAttributes(
      title: Map<String, String>.from(json['title'] ?? {}),
      altTitles: (json['altTitles'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
      description: Map<String, String>.from(json['description'] ?? {}),
      isLocked: json['isLocked'] ?? false,
      links: Map<String, dynamic>.from(json['links'] ?? {}),
      originalLanguage: json['originalLanguage'] ?? '',
      lastVolume: json['lastVolume'] ?? '',
      lastChapter: json['lastChapter'] ?? '',
      publicationDemographic: json['publicationDemographic'] ?? '',
      status: json['status'] ?? '',
      year: json['year'],
      contentRating: json['contentRating'] ?? '',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => MangaTag.fromJson(e))
              .toList() ??
          [],
      state: json['state'] ?? '',
      chapterNumbersResetOnNewVolume:
          json['chapterNumbersResetOnNewVolume'] ?? false,
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      version: json['version'] ?? 0,
      availableTranslatedLanguages:
          (json['availableTranslatedLanguages'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
      latestUploadedChapter: json['latestUploadedChapter'],
    );
  }
}

class MangaTag {
  final String id;
  final String type;
  final MangaTagAttributes attributes;

  MangaTag({
    required this.id,
    required this.type,
    required this.attributes,
  });

  factory MangaTag.fromJson(Map<String, dynamic> json) {
    return MangaTag(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      attributes: MangaTagAttributes.fromJson(json['attributes']),
    );
  }
}

class MangaTagAttributes {
  final Map<String, String> name;
  final Map<String, String> description;
  final String group;
  final int version;

  MangaTagAttributes({
    required this.name,
    required this.description,
    required this.group,
    required this.version,
  });

  factory MangaTagAttributes.fromJson(Map<String, dynamic> json) {
    return MangaTagAttributes(
      name: Map<String, String>.from(json['name'] ?? {}),
      description: Map<String, String>.from(json['description'] ?? {}),
      group: json['group'] ?? '',
      version: json['version'] ?? 0,
    );
  }
}

class MangaRelationship {
  final String id;
  final String type;
  final String? related;

  MangaRelationship({
    required this.id,
    required this.type,
    this.related,
  });

  factory MangaRelationship.fromJson(Map<String, dynamic> json) {
    return MangaRelationship(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      related: json['related'],
    );
  }
}
