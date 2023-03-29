import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mobile_apps/components/ErrorPage.dart';
import 'package:mobile_apps/components/GreySeparator.dart';
import 'package:mobile_apps/components/LoadingDialog.dart';
import 'package:mobile_apps/helper/FilterRequest.dart';
import 'package:mobile_apps/models/tenant.dart';
import 'package:mobile_apps/pages/outlet/DetailPage.dart';
import 'package:mobile_apps/repository/BaseRepository.dart';
import 'package:skeletons/skeletons.dart';
import 'package:mobile_apps/components/NoData.dart';

import 'package:mobile_apps/components/AppDialog.dart';
import '../components/ListItem.dart';
import 'package:mobile_apps/constants/color.dart' as color;

// ignore: must_be_immutable
class ListViewBuilder extends StatefulWidget {
  List<tenant> data;
  // final bool isInit;
  // final bool hasMore;
  // final Future<void> Function(bool) fetch;

  ListViewBuilder({
    super.key,
    required this.data,
    // required this.fetch,
    // required this.isInit,
    // required this.hasMore,
  });

  @override
  State<ListViewBuilder> createState() => _ListViewBuilderState();
}

class _ListViewBuilderState extends State<ListViewBuilder> with TickerProviderStateMixin{
  late ScrollController controller;
  late final GlobalKey<AnimatedListState> _listKey;
  late final Tween<Offset>? _animatedTween;
  var loadingDialog = LoadingDialog();
  final repo = BaseRepository("tenant");


  bool isLoading = false;
  String? errorMessage;
  late FilterRequest filterRequest;
  late List<tenant> data = [];

  @override
  void initState() {
    super.initState();
    _listKey = GlobalKey();
    isLoading = true;
    _animatedTween = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    );
    controller = ScrollController()..addListener(() {});
  }

  @override
  void dispose() {
    controller.removeListener(() {});
    super.dispose();
  }

  @override
  @protected
  void didUpdateWidget(covariant ListViewBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (data.length != widget.data.length) {
      for (var item in widget.data) {
        if (data.indexWhere((r) => r.id == item.id) < 0) {
          final int index = data.length;
          data.insert(index, item);
          _listKey.currentState?.insertItem(index, duration: const Duration(milliseconds: 0) );
        }
        setState(() { isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return ErrorPage(message: errorMessage!);
    }
    if (isLoading) {
      return Skeleton(
        isLoading: true,
        skeleton: SkeletonListView(itemCount: 20, scrollable: false,),
        child: Container(),
      );
    }

    if (data.isEmpty) {
      return const NoData();
    }

    return Column(
      children: [
        Expanded(
          child: AnimatedList(
            key: _listKey,
            initialItemCount: data.length,
            // physics: const NeverScrollableScrollPhysics(),
            controller: controller,
            shrinkWrap: true,
            itemBuilder: (context, index, animation) {
              return Slidable(
                enabled: true,
                key: ValueKey(data[index].id),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.6,
                  children: [
                    SlidableAction(
                      onPressed: (BuildContext context) async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => DetailPage(recordId: data[index].id)),
                        );
                        if (result != null && !result["isNew"]) {
                          setState(() {
                            data[index] = result["value"];
                          });
                        }
                      },
                      backgroundColor: const Color(0xFF21B7CA),
                      foregroundColor: Colors.white,
                      icon: Icons.edit_outlined,
                      label: 'Ubah',
                    ),
                    SlidableAction(
                      onPressed: (BuildContext context) async {
                        await appDialog(DialogType.Confirm,
                          dialogText: "Apakah yakin ingin menutup outlet ini?",
                          hasDescription: false,
                          callback: (value) => {
                            if (value) {
                              Future.delayed(const Duration(seconds: 0), () async {
                                await removeItem(index);
                              },),
                            }
                          }
                        );
                      },
                      backgroundColor: color.primary,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Tutup',
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ListItem(
                      index: index,
                      data: data[index],
                    ),
                    const GreySeparator(),
                  ],
                ),
              );
            }
          ),
        ),
      ],
    );
  }

  Future<void> addItem(tenant item) async {
    int insertedIndex = data.length;
    data.insert(insertedIndex, item);

    _listKey.currentState?.insertItem(insertedIndex, duration: const Duration(milliseconds: 10));
  }

  Future<void> removeItem(int index) async {
    String? id = data[index].id;
    await loadingDialog.show();

    var response = await repo.deleteById(id: id!);
    if (response.success) {
      data.removeAt(index);

      final removedItem = data[index];
      _listKey!.currentState?.removeItem(index, (context, animation) => SlideTransition(
          position: animation.drive(_animatedTween!),
          child: ListItem(
            index: index,
            data: removedItem,
          ),
        )
      );

      Future.delayed(const Duration(seconds: 0), () async {
        await loadingDialog.hide();
        await appDialog(response.success ? DialogType.Success : DialogType.Warning, dialogText: response.message);
      },);
    }
  }
}
