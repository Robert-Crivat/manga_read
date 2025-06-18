class DataManager {
  String? status;
  String? messaggio;
  dynamic parametri;

  DataManager({this.status, this.messaggio, this.parametri});

  DataManager.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    messaggio = json['messaggio'];
    parametri = json['data'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = this.status;
    data['messaggio'] = this.messaggio;
    data['data'] = this.parametri;
    return data;
  }
}
