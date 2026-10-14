enum SubjectStatus { warning, safe, critical }

class StudentSubjectModel {
  final String code;
  final String modality;
  final String room;
  final String name;
  final String schedule;
  final String professor;
  final double currentGrade;
  final String statusLabel;
  final String statusSubLabel;
  final String targetHeader;
  final String targetValue;
  final String bottomLeftNote;
  final String bottomRightNote;
  final int attendancePercent;
  final String attendanceNote;
  final String absencesBadge;
  final SubjectStatus status;

  const StudentSubjectModel({
    required this.code,
    required this.modality,
    required this.room,
    required this.name,
    required this.schedule,
    required this.professor,
    required this.currentGrade,
    required this.statusLabel,
    required this.statusSubLabel,
    required this.targetHeader,
    required this.targetValue,
    required this.bottomLeftNote,
    required this.bottomRightNote,
    required this.attendancePercent,
    required this.attendanceNote,
    required this.absencesBadge,
    required this.status,
  });
}