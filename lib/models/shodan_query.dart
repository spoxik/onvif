class ShodanQuery {
  const ShodanQuery({
    required this.name,
    required this.query,
  });

  final String name;
  final String query;

  Map<String, dynamic> toJson() => {
        'name': name,
        'query': query,
      };

  factory ShodanQuery.fromJson(Map<String, dynamic> json) {
    return ShodanQuery(
      name: json['name']?.toString() ?? 'Zapytanie',
      query: json['query']?.toString() ?? '',
    );
  }
}
