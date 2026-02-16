enum TechnicianStatus {
  online,
  offline,
  busy;

  String get arabicLabel {
    switch (this) {
      case TechnicianStatus.online:
        return 'متصل';
      case TechnicianStatus.offline:
        return 'غير متصل';
      case TechnicianStatus.busy:
        return 'مشغول';
    }
  }

  bool get isAvailable => this == TechnicianStatus.online;
}
