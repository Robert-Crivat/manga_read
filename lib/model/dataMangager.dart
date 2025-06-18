class DataManager {
  String? status;
  String? messaggio;
  dynamic parametri;

  DataManager({this.status, this.messaggio, this.parametri});

  DataManager.fromJson(Map<String, dynamic> json) {
    status = json['result'];
    messaggio = json['response'];
    parametri = json['data'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['result'] = this.status;
    data['response'] = this.messaggio;
    data['data'] = this.parametri;
    return data;
  }
}
