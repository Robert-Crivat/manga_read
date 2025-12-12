class DataManager {
  String? status;
  String? messaggio;
  dynamic parametri;
  dynamic data; // Per accedere a tutti i dati della risposta

  DataManager({this.status, this.messaggio, this.parametri, this.data});

  DataManager.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    messaggio = json['messaggio'];
    parametri = json['data'];
    data = json; // Memorizza l'intera risposta JSON
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = this.status;
    data['messaggio'] = this.messaggio;
    data['data'] = this.parametri;
    return data;
  }
}
