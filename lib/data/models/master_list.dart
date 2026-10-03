/// A row of `public.master_lists` plus its student count.
class MasterList {
  const MasterList({
    required this.id,
    required this.name,
    this.studentCount = 0,
  });

  final String id;
  final String name;
  final int studentCount;

  factory MasterList.fromJson(Map<String, dynamic> json, {int count = 0}) =>
      MasterList(
        id: json['id'] as String,
        name: json['name'] as String,
        studentCount: count,
      );
}
