class CompanyModel {
  final int id;
  final String name;
  final String? logoUrl;
  final String industry;
  final String headquarters;
  final bool isVerified;

  CompanyModel({
    required this.id,
    required this.name,
    this.logoUrl,
    this.industry = 'Technology',
    this.headquarters = 'San Francisco, CA',
    this.isVerified = false,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      logoUrl: json['logo_url'] ?? json['logo'],
      industry: json['industry'] ?? 'Technology',
      headquarters: json['headquarters'] ?? 'San Francisco, CA',
      isVerified: json['is_verified'] ?? false,
    );
  }
}

class JobModel {
  final int id;
  final String title;
  final CompanyModel? company;
  final String description;
  final String responsibilities;
  final String requirements;
  final String benefits;
  final String jobType;
  final String workplaceType;
  final String experienceLevel;
  final double? minSalary;
  final double? maxSalary;
  final String currency;
  final String location;
  final String status;
  final int viewsCount;
  final int applicationsCount;
  final bool isSaved;
  final List<String> skills;
  final double? matchPercentage;
  final String? aiRationale;
  final DateTime? createdAt;

  JobModel({
    required this.id,
    required this.title,
    this.company,
    required this.description,
    this.responsibilities = '',
    this.requirements = '',
    this.benefits = '',
    this.jobType = 'FULL_TIME',
    this.workplaceType = 'REMOTE',
    this.experienceLevel = 'MID',
    this.minSalary,
    this.maxSalary,
    this.currency = 'USD',
    this.location = 'Remote',
    this.status = 'ACTIVE',
    this.viewsCount = 0,
    this.applicationsCount = 0,
    this.isSaved = false,
    this.skills = const [],
    this.matchPercentage,
    this.aiRationale,
    this.createdAt,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedSkills = [];
    if (json['required_skills'] != null && json['required_skills'] is List) {
      parsedSkills = (json['required_skills'] as List)
          .map((s) => s['skill_name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (json['matched_skills'] != null && json['matched_skills'] is List) {
      parsedSkills = List<String>.from(json['matched_skills']);
    }

    CompanyModel? comp;
    if (json['company'] != null && json['company'] is Map<String, dynamic>) {
      comp = CompanyModel.fromJson(json['company']);
    } else if (json['company_name'] != null) {
      comp = CompanyModel(
        id: 0,
        name: json['company_name'],
        logoUrl: json['company_logo'],
      );
    }

    double? toDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    int toInt(dynamic val, [int def = 0]) {
      if (val == null) return def;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? def;
      return def;
    }

    return JobModel(
      id: toInt(json['id']),
      title: json['title'] ?? '',
      company: comp,
      description: json['description'] ?? '',
      responsibilities: json['responsibilities'] ?? '',
      requirements: json['requirements'] ?? '',
      benefits: json['benefits'] ?? '',
      jobType: json['job_type'] ?? 'FULL_TIME',
      workplaceType: json['workplace_type'] ?? 'REMOTE',
      experienceLevel: json['experience_level'] ?? 'MID',
      minSalary: toDouble(json['min_salary']),
      maxSalary: toDouble(json['max_salary']),
      currency: json['currency'] ?? 'USD',
      location: json['location'] ?? 'Remote',
      status: json['status'] ?? 'ACTIVE',
      viewsCount: toInt(json['views_count']),
      applicationsCount: toInt(json['applications_count']),
      isSaved: json['is_saved'] ?? false,
      skills: parsedSkills,
      matchPercentage: toDouble(json['match_percentage']),
      aiRationale: json['ai_rationale'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}
