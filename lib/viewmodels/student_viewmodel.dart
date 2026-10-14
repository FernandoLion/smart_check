import 'package:flutter/material.dart';
import '../models/student_subject_model.dart';

class StudentViewModel extends ChangeNotifier {
  final int globalAttendance = 91;
  final String globalAttendanceStatus = 'Normal';
  final int enrolledCredits = 18;
  final int maxCredits = 18;
  final String currentPeriod = '2025-1';
  final String evaluationProgress = 'Corte 2 • 70% Evaluado';

  final List<StudentSubjectModel> _subjects = const [
    // TARJETA 1: Estado de Atención (Ámbar)
    StudentSubjectModel(
      code: 'SIS-402',
      modality: 'Presencial',
      room: 'Edif. 4 • Aula 204',
      name: 'Ingeniería de Software II',
      schedule: 'Mar / Jue • 08:00 - 10:00',
      professor: 'Ing. R. Morales',
      currentGrade: 3.2,
      statusLabel: 'En Riesgo Leve',
      statusSubLabel: 'Parcial 2 en curso',
      targetHeader: 'Para Aprobar',
      targetValue: 'Faltan 1.3 pts',
      bottomLeftNote: 'Meta mínima: 3.0 / 5.0',
      bottomRightNote: 'Aporte restante: 30% (Final)',
      attendancePercent: 82,
      attendanceNote: '(Mínimo 80%)',
      absencesBadge: '4 faltas restantes permitidas',
      status: SubjectStatus.warning,
    ),
    // TARJETA 2: Estado Seguro (Verde)
    StudentSubjectModel(
      code: 'SIS-301',
      modality: 'Laboratorio',
      room: 'Lab Sistemas 3',
      name: 'Arquitectura de Software',
      schedule: 'Lun / Mié • 10:00 - 12:00',
      professor: 'Dra. C. Valencia',
      currentGrade: 4.5,
      statusLabel: 'Aprobando',
      statusSubLabel: 'Rendimiento Superior',
      targetHeader: 'Exigencia',
      targetValue: '0.0 req',
      bottomLeftNote: '¡Materia prácticamente asegurada!',
      bottomRightNote: 'Faltan 0.0 para aprobar',
      attendancePercent: 96,
      attendanceNote: '(Excepcional)',
      absencesBadge: 'Sin riesgo de inasistencia',
      status: SubjectStatus.safe,
    ),
    // TARJETA 3: Estado Crítico / Alerta (Rojo)
    StudentSubjectModel(
      code: 'SIS-505',
      modality: 'Clase Magistral',
      room: 'Auditorio B',
      name: 'Sistemas Distribuidos y Redes',
      schedule: 'Viernes • 14:00 - 18:00',
      professor: 'Dr. G. Mendoza',
      currentGrade: 2.7,
      statusLabel: 'Riesgo Alto',
      statusSubLabel: 'Requiere Atención',
      targetHeader: 'Exigencia Final',
      targetValue: 'Faltan 1.8 pts',
      bottomLeftNote: 'Examen final 30% decisivo',
      bottomRightNote: 'Puntaje obj: 3.5 / 5.0',
      attendancePercent: 76,
      attendanceNote: '(Límite reprobación: 75%)',
      absencesBadge: '0 faltas disponibles',
      status: SubjectStatus.critical,
    ),
  ];

  List<StudentSubjectModel> get subjects => _subjects;
}