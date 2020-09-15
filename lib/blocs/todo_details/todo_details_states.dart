import 'package:equatable/equatable.dart';
import 'package:qunderlist/repository/repository.dart';

abstract class TodoDetailsState with EquatableMixin {
  @override
  bool get stringify => true;
}

class TodoDetailsLoading extends TodoDetailsState {
  @override
  List<Object> get props => [];
}

class TodoDetailsLoadedShortItem extends TodoDetailsState {
  final TodoItemBase item;
  TodoDetailsLoadedShortItem(this.item);

  @override
  List<Object> get props => [item];
}

class TodoDetailsFullyLoaded extends TodoDetailsState {
  final TodoItem item;
  TodoDetailsFullyLoaded(this.item);

  @override
  List<Object> get props => [item];
}