import 'package:equatable/equatable.dart';
import 'package:qunderlist/repository/models.dart';

class RepeatedState with EquatableMixin {
  final Repeated repeated;
  final bool allowAutoComplete;
  final bool valid;

  RepeatedState(this.repeated, this.allowAutoComplete, this.valid);

  @override
  List<Object> get props => [repeated, allowAutoComplete, valid];
}