class ScholarshipModel {
  final String id;
  final String title;
  final String amount;
  final String description;
  final String deadline;

  ScholarshipModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.description,
    required this.deadline,
  });

  factory ScholarshipModel.fromMap(
      Map<String, dynamic> map, String id) {
    return ScholarshipModel(
      id: id,
      title: map["title"] ?? "",
      amount: map["amount"] ?? "",
      description: map["description"] ?? "",
      deadline: map["deadline"] ?? "",
    );
  }
}