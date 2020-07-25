///
/// 全局常量和变量
///
/// created by keng42 @2019-08-14 12:37:23
///

// 图片文件在本地的状态：未知、确认已存在、确认不在本地
// 从而可以对应的显示不同的图片
const int STATUS_FILE_UNKNOW = 0;
const int STATUS_FILE_EXISTS = 1;
const int STATUS_FILE_MISSED = 2;

// 当前是否处于锁定状态
bool vIsLocked = true;
