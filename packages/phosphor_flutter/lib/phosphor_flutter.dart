/// 本地补丁版 phosphor_flutter 2.1.0：官方包的 PhosphorIconData 继承了在新版 Flutter 中已是 final 的 IconData，
/// 无法编译。这里把图标常量直接改为 IconData（字体文件与 codePoint 不变），仅保留 Regular / Fill / Bold 三种。
library phosphor_flutter;

export 'src/phosphor_icons_regular.dart';
export 'src/phosphor_icons_fill.dart';
export 'src/phosphor_icons_bold.dart';
