import 'dart:io';
import 'dart:convert';
import '../db/database_helper.dart';
import '../models/course.dart';
import '../models/chapter.dart';

class WebServerService {
  static final WebServerService instance = WebServerService._();
  WebServerService._();

  HttpServer? _server;
  bool _running = false;
  int _port = 8080;

  bool get isRunning => _running;
  int get port => _port;

  Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> start({int port = 8080}) async {
    if (_running) return true;
    _port = port;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _running = true;
      _server!.listen(_handleRequest);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
    }
    _running = false;
  }

  void _handleRequest(HttpRequest request) {
    final path = request.uri.path;
    final method = request.method;

    try {
      if (path == '/' && method == 'GET') {
        _serveHtml(request);
      } else if (path.startsWith('/api/')) {
        _handleApi(request, method, path);
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not Found');
        request.response.close();
      }
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('Error: $e');
      request.response.close();
    }
  }

  void _serveHtml(HttpRequest request) {
    request.response.headers.contentType = ContentType.html;
    request.response.write(_htmlContent);
    request.response.close();
  }

  void _handleApi(HttpRequest request, String method, String path) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;

    try {
      if (path == '/api/types' && method == 'GET') {
        final types = await DatabaseHelper.instance.getAllCourseTypes();
        response.write(jsonEncode(types.map((t) => t.toMap()).toList()));
      } else if (path == '/api/courses' && method == 'GET') {
        final courses = await DatabaseHelper.instance.getAllCourses();
        final result = <Map<String, dynamic>>[];
        for (var c in courses) {
          if (c.id != null) {
            final p = await DatabaseHelper.instance.getCourseProgress(c.id!);
            result.add({
              ...c.toMap(),
              'type_name': c.typeName,
              'completed': p['completed'],
              'studying': p['studying'],
              'total': p['total'],
            });
          }
        }
        response.write(jsonEncode(result));
      } else if (path == '/api/courses' && method == 'POST') {
        final body = await _readBody(request);
        final course = Course(
          courseName: body['course_name'] ?? '',
          desc: body['desc'],
          typeId: body['type_id'],
          expectedChapters: body['expected_chapters'],
          createTime: DateTime.now(),
        );
        final id = await DatabaseHelper.instance.insertCourse(course);
        response.write(jsonEncode({'success': true, 'id': id}));
      } else if (path.startsWith('/api/courses/') && method == 'DELETE') {
        final id = int.tryParse(path.split('/').last);
        if (id != null) {
          await DatabaseHelper.instance.deleteCourse(id);
          response.write(jsonEncode({'success': true}));
        } else {
          response.statusCode = HttpStatus.badRequest;
          response.write(jsonEncode({'error': 'Invalid id'}));
        }
      } else if (path.startsWith('/api/courses/') && method == 'PUT') {
        final id = int.tryParse(path.split('/').last);
        if (id != null) {
          final body = await _readBody(request);
          final course = Course(
            id: id,
            courseName: body['course_name'] ?? '',
            desc: body['desc'],
            typeId: body['type_id'],
            expectedChapters: body['expected_chapters'],
            createTime: DateTime.now(),
          );
          await DatabaseHelper.instance.updateCourse(course);
          response.write(jsonEncode({'success': true}));
        } else {
          response.statusCode = HttpStatus.badRequest;
          response.write(jsonEncode({'error': 'Invalid id'}));
        }
      } else if (path.startsWith('/api/chapters/') && method == 'GET') {
        final id = int.tryParse(path.split('/').last);
        if (id != null) {
          final chapters = await DatabaseHelper.instance.getChaptersByCourseId(id);
          response.write(jsonEncode(chapters.map((c) => c.toMap()).toList()));
        } else {
          response.statusCode = HttpStatus.badRequest;
          response.write(jsonEncode({'error': 'Invalid id'}));
        }
      } else if (path == '/api/chapters' && method == 'POST') {
        final body = await _readBody(request);
        final chapter = Chapter(
          courseId: body['course_id'] ?? 0,
          title: body['title'] ?? '',
          number: body['number'],
          status: body['status'] ?? 1,
          studyDate: body['study_date'] != null
              ? DateTime.tryParse(body['study_date'])
              : null,
          remark: body['remark'],
          createTime: DateTime.now(),
        );
        final cid = await DatabaseHelper.instance.insertChapter(chapter);
        response.write(jsonEncode({'success': true, 'id': cid}));
      } else if (path.startsWith('/api/chapters/') && method == 'PUT') {
        final id = int.tryParse(path.split('/').last);
        if (id != null) {
          final body = await _readBody(request);
          final chapter = Chapter(
            id: id,
            courseId: body['course_id'] ?? 0,
            title: body['title'] ?? '',
            number: body['number'],
            status: body['status'] ?? 1,
            studyDate: body['study_date'] != null
                ? DateTime.tryParse(body['study_date'])
                : null,
            remark: body['remark'],
            createTime: DateTime.now(),
          );
          await DatabaseHelper.instance.updateChapter(chapter);
          response.write(jsonEncode({'success': true}));
        } else {
          response.statusCode = HttpStatus.badRequest;
          response.write(jsonEncode({'error': 'Invalid id'}));
        }
      } else if (path.startsWith('/api/chapters/') && method == 'DELETE') {
        final id = int.tryParse(path.split('/').last);
        if (id != null) {
          await DatabaseHelper.instance.deleteChapter(id);
          response.write(jsonEncode({'success': true}));
        } else {
          response.statusCode = HttpStatus.badRequest;
          response.write(jsonEncode({'error': 'Invalid id'}));
        }
      } else {
        response.statusCode = HttpStatus.notFound;
        response.write(jsonEncode({'error': 'Not found'}));
      }
    } catch (e) {
      response.statusCode = HttpStatus.internalServerError;
      response.write(jsonEncode({'error': '$e'}));
    }
    response.close();
  }

  Future<Map<String, dynamic>> _readBody(HttpRequest request) async {
    final content = await utf8.decoder.bind(request).join();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  String get _htmlContent => '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>学习进度 - 网页管理</title>
<style>
:root {
  --md-primary: #6750A4;
  --md-on-primary: #FFFFFF;
  --md-primary-container: #EADDFF;
  --md-on-primary-container: #21005D;
  --md-surface: #FEF7FF;
  --md-surface-variant: #E7E0EC;
  --md-on-surface: #1D1B20;
  --md-on-surface-variant: #49454F;
  --md-outline: #79747E;
  --md-error: #BA1A1A;
  --md-secondary: #625B71;
  --md-tertiary: #7D5260;
  --md-green: #2E7D32;
  --md-orange: #E65100;
}
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: var(--md-surface); color: var(--md-on-surface); }
.app-bar { background: var(--md-surface); padding: 16px 20px; display: flex; align-items: center; gap: 12px; border-bottom: 1px solid var(--md-surface-variant); position: sticky; top: 0; z-index: 100; }
.app-bar h1 { font-size: 20px; font-weight: 500; flex: 1; }
.container { max-width: 800px; margin: 0 auto; padding: 16px; }
.fab { position: fixed; bottom: 24px; right: 24px; width: 56px; height: 56px; border-radius: 16px; background: var(--md-primary); color: var(--md-on-primary); border: none; font-size: 24px; cursor: pointer; box-shadow: 0 3px 8px rgba(0,0,0,0.2); transition: 0.2s; z-index: 50; }
.fab:hover { box-shadow: 0 6px 12px rgba(0,0,0,0.3); transform: scale(1.05); }
.card { background: white; border-radius: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.12); margin-bottom: 12px; overflow: hidden; }
.type-header { padding: 12px 16px; background: var(--md-primary-container); display: flex; align-items: center; gap: 8px; cursor: pointer; }
.type-header h2 { font-size: 15px; font-weight: 600; color: var(--md-on-primary-container); flex: 1; }
.type-header .count { font-size: 12px; color: var(--md-on-primary-container); opacity: 0.8; }
.type-header .arrow { transition: transform 0.2s; }
.type-header.collapsed .arrow { transform: rotate(-90deg); }
.type-body { display: block; }
.type-body.collapsed { display: none; }
.course-card { padding: 16px; border-bottom: 1px solid var(--md-surface-variant); }
.course-card:last-child { border-bottom: none; }
.course-title { font-size: 16px; font-weight: 500; margin-bottom: 4px; display: flex; align-items: center; gap: 8px; }
.type-tag { font-size: 11px; padding: 2px 8px; border-radius: 4px; background: var(--md-primary-container); color: var(--md-on-primary-container); }
.course-desc { font-size: 13px; color: var(--md-on-surface-variant); margin-bottom: 8px; }
.progress-row { display: flex; align-items: center; gap: 12px; margin: 8px 0; }
.progress-bar { flex: 1; height: 8px; background: var(--md-surface-variant); border-radius: 4px; overflow: hidden; }
.progress-fill { height: 100%; background: var(--md-primary); border-radius: 4px; transition: width 0.3s; }
.progress-text { font-size: 13px; font-weight: 500; color: var(--md-primary); white-space: nowrap; }
.status-row { display: flex; gap: 16px; font-size: 12px; color: var(--md-on-surface-variant); }
.status-badge { padding: 2px 8px; border-radius: 4px; font-size: 11px; }
.status-studying { background: #FFF3E0; color: var(--md-orange); }
.status-completed { background: #E8F5E9; color: var(--md-green); }
.action-row { display: flex; gap: 8px; margin-top: 12px; }
.btn { padding: 6px 16px; border: none; border-radius: 20px; cursor: pointer; font-size: 13px; transition: 0.2s; }
.btn-filled { background: var(--md-primary); color: var(--md-on-primary); }
.btn-filled:hover { filter: brightness(1.1); }
.btn-tonal { background: var(--md-primary-container); color: var(--md-on-primary-container); }
.btn-outlined { background: transparent; border: 1px solid var(--md-outline); color: var(--md-primary); }
.btn-danger { background: var(--md-error); color: white; }
.btn-text { background: transparent; color: var(--md-primary); }
.chapter-section { margin-top: 12px; padding: 12px; background: var(--md-surface); border-radius: 12px; }
.chapter-item { padding: 10px 12px; background: white; border-radius: 8px; margin-bottom: 6px; display: flex; justify-content: space-between; align-items: center; font-size: 14px; box-shadow: 0 1px 2px rgba(0,0,0,0.05); }
.chapter-info { display: flex; align-items: center; gap: 8px; flex: 1; }
.chapter-number { font-size: 12px; color: var(--md-outline); }
.modal-overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.4); display: none; justify-content: center; align-items: center; z-index: 1000; }
.modal-overlay.active { display: flex; }
.modal { background: var(--md-surface); border-radius: 28px; padding: 24px; width: 90%; max-width: 480px; max-height: 85vh; overflow-y: auto; }
.modal h2 { font-size: 22px; font-weight: 400; margin-bottom: 20px; }
.form-group { margin-bottom: 16px; }
.form-group label { display: block; margin-bottom: 6px; font-size: 13px; color: var(--md-on-surface-variant); }
.form-group input, .form-group select, .form-group textarea { width: 100%; padding: 10px 12px; border: 1px solid var(--md-outline); border-radius: 8px; font-size: 14px; background: var(--md-surface); }
.form-group input:focus, .form-group select:focus, .form-group textarea:focus { outline: none; border-color: var(--md-primary); border-width: 2px; }
.form-group textarea { resize: vertical; min-height: 60px; }
.modal-actions { display: flex; gap: 8px; margin-top: 24px; justify-content: flex-end; }
.empty-state { text-align: center; padding: 48px 20px; color: var(--md-outline); }
.empty-state .icon { font-size: 48px; margin-bottom: 16px; }
</style>
</head>
<body>
<div class="app-bar">
  <span style="font-size:24px">📚</span>
  <h1>学习进度</h1>
</div>
<div class="container" id="mainContent">
  <div class="empty-state"><div class="icon">⏳</div>加载中...</div>
</div>
<button class="fab" onclick="openCourseModal()" title="添加课程">+</button>

<div class="modal-overlay" id="courseModal">
  <div class="modal">
    <h2 id="courseModalTitle">添加课程</h2>
    <input type="hidden" id="courseId">
    <div class="form-group"><label>课程名称</label><input type="text" id="courseName"></div>
    <div class="form-group"><label>课程类型</label><select id="courseType"></select></div>
    <div class="form-group"><label>总章节数（可选）</label><input type="number" id="expectedChapters"></div>
    <div class="form-group"><label>描述</label><textarea id="courseDesc"></textarea></div>
    <div class="modal-actions">
      <button class="btn btn-text" onclick="closeCourseModal()">取消</button>
      <button class="btn btn-filled" onclick="saveCourse()">保存</button>
    </div>
  </div>
</div>

<div class="modal-overlay" id="chapterModal">
  <div class="modal">
    <h2 id="chapterModalTitle">添加章节</h2>
    <input type="hidden" id="chapterId">
    <input type="hidden" id="chapterCourseId">
    <div class="form-group"><label>章节标题</label><input type="text" id="chapterTitle"></div>
    <div class="form-group"><label>章节序号</label><input type="text" id="chapterNumber"></div>
    <div class="form-group"><label>状态</label><select id="chapterStatus"><option value="1">学习中</option><option value="2">已完成</option></select></div>
    <div class="form-group"><label>学习日期</label><input type="date" id="chapterDate"></div>
    <div class="form-group"><label>备注</label><textarea id="chapterRemark"></textarea></div>
    <div class="modal-actions">
      <button class="btn btn-danger" id="deleteChapterBtn" onclick="deleteChapter()" style="display:none">删除</button>
      <span style="flex:1"></span>
      <button class="btn btn-text" onclick="closeChapterModal()">取消</button>
      <button class="btn btn-filled" onclick="saveChapter()">保存</button>
    </div>
  </div>
</div>

<script>
let types = [];
let allCourses = [];

function esc(s) { if(!s) return ''; return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;'); }

async function loadTypes() {
  const res = await fetch('/api/types');
  types = await res.json();
}

async function loadCourses() {
  const res = await fetch('/api/courses');
  allCourses = await res.json();
  renderCourses();
}

function renderCourses() {
  const container = document.getElementById('mainContent');
  if (allCourses.length === 0) {
    container.innerHTML = '<div class="empty-state"><div class="icon">📖</div><p>暂无课程，点击右下角 + 添加</p></div>';
    return;
  }

  // 按类型分组
  const grouped = {};
  const typeOrder = [];
  for (const t of types) {
    if (!grouped[t.id]) { grouped[t.id] = { name: t.name, courses: [] }; typeOrder.push(t.id); }
  }
  grouped['null'] = { name: '未分类', courses: [] };
  typeOrder.push('null');

  for (const c of allCourses) {
    const key = c.type_id != null ? c.type_id : 'null';
    if (!grouped[key]) { grouped[key] = { name: c.type_name || '未分类', courses: [] }; typeOrder.push(key); }
    grouped[key].courses.push(c);
  }

  let html = '';
  for (const key of typeOrder) {
    const group = grouped[key];
    if (!group || group.courses.length === 0) continue;
    const groupId = 'type_' + key;
    html += '<div class="card">';
    html += '<div class="type-header" onclick="toggleType(\\''+groupId+'\\')">';
    html += '<span>📁</span>';
    html += '<h2>' + esc(group.name) + '</h2>';
    html += '<span class="count">' + group.courses.length + ' 个课程</span>';
    html += '<span class="arrow">▼</span>';
    html += '</div>';
    html += '<div class="type-body" id="'+groupId+'">';
    for (const c of group.courses) {
      html += renderCourseCard(c);
    }
    html += '</div>';
    html += '</div>';
  }
  container.innerHTML = html;
}

function renderCourseCard(c) {
  const total = c.total || 0;
  const completed = c.completed || 0;
  const studying = c.studying || 0;
  const percent = total > 0 ? (completed/total*100).toFixed(0) : 0;
  let html = '<div class="course-card">';
  html += '<div class="course-title">' + esc(c.course_name);
  if (c.expected_chapters) html += '<span class="type-tag">' + c.expected_chapters + '章</span>';
  html += '</div>';
  if (c.desc) html += '<div class="course-desc">' + esc(c.desc) + '</div>';
  html += '<div class="progress-row">';
  html += '<div class="progress-bar"><div class="progress-fill" style="width:'+percent+'%"></div></div>';
  html += '<span class="progress-text">' + completed + '/' + total + '</span>';
  html += '</div>';
  html += '<div class="status-row">';
  html += '<span class="status-badge status-studying">学习中 ' + studying + '</span>';
  html += '<span class="status-badge status-completed">已完成 ' + completed + '</span>';
  html += '</div>';
  html += '<div class="action-row">';
  html += '<button class="btn btn-tonal" onclick="event.stopPropagation();toggleChapters('+c.id+')">章节管理</button>';
  html += '<button class="btn btn-outlined" onclick="event.stopPropagation();editCourse('+c.id+')">编辑</button>';
  html += '<button class="btn btn-text" style="color:var(--md-error)" onclick="event.stopPropagation();deleteCourse('+c.id+')">删除</button>';
  html += '</div>';
  html += '<div class="chapter-section" id="chapters_'+c.id+'" style="display:none"></div>';
  html += '</div>';
  return html;
}

function toggleType(id) {
  const body = document.getElementById(id);
  const header = body.previousElementSibling;
  body.classList.toggle('collapsed');
  header.classList.toggle('collapsed');
}

async function toggleChapters(courseId) {
  const div = document.getElementById('chapters_' + courseId);
  if (div.style.display === 'none') {
    const res = await fetch('/api/chapters/' + courseId);
    const chapters = await res.json();
    div.style.display = 'block';
    let html = '<button class="btn btn-filled" style="margin-bottom:8px" onclick="openChapterModal('+courseId+')">+ 添加章节</button>';
    if (chapters.length === 0) {
      html += '<p style="text-align:center;color:var(--md-outline);padding:12px">暂无章节</p>';
    } else {
      for (const ch of chapters) {
        const st = ch.status === 2 ? '<span class="status-badge status-completed">已完成</span>' : '<span class="status-badge status-studying">学习中</span>';
        const num = ch.number ? '<span class="chapter-number">#'+esc(ch.number)+'</span>' : '';
        const date = ch.study_date ? '<span style="font-size:11px;color:var(--md-outline)">'+ch.study_date.substring(0,10)+'</span>' : '';
        html += '<div class="chapter-item">';
        html += '<div class="chapter-info">' + num + '<span>' + esc(ch.title) + '</span>' + st + date + '</div>';
        html += '<div style="display:flex;gap:4px">';
        html += '<button class="btn btn-text" style="font-size:12px;padding:4px 8px" onclick="editChapter('+ch.id+','+courseId+')">编辑</button>';
        html += '<button class="btn btn-text" style="font-size:12px;padding:4px 8px;color:var(--md-error)" onclick="deleteChapterById('+ch.id+','+courseId+')">删除</button>';
        html += '</div></div>';
      }
    }
    div.innerHTML = html;
  } else {
    div.style.display = 'none';
  }
}

function openCourseModal() {
  document.getElementById('courseModalTitle').textContent = '添加课程';
  document.getElementById('courseId').value = '';
  document.getElementById('courseName').value = '';
  document.getElementById('courseDesc').value = '';
  document.getElementById('expectedChapters').value = '';
  const sel = document.getElementById('courseType');
  sel.innerHTML = types.map(t => '<option value="'+t.id+'">'+esc(t.name)+'</option>').join('');
  document.getElementById('courseModal').classList.add('active');
}

function editCourse(id) {
  const c = allCourses.find(x => x.id === id);
  if (!c) return;
  document.getElementById('courseModalTitle').textContent = '编辑课程';
  document.getElementById('courseId').value = id;
  document.getElementById('courseName').value = c.course_name || '';
  document.getElementById('courseDesc').value = c.desc || '';
  document.getElementById('expectedChapters').value = c.expected_chapters || '';
  const sel = document.getElementById('courseType');
  sel.innerHTML = types.map(t => '<option value="'+t.id+'" '+(t.id===c.type_id?'selected':'')+'>'+esc(t.name)+'</option>').join('');
  document.getElementById('courseModal').classList.add('active');
}

function closeCourseModal() { document.getElementById('courseModal').classList.remove('active'); }

async function saveCourse() {
  const id = document.getElementById('courseId').value;
  const data = {
    course_name: document.getElementById('courseName').value,
    desc: document.getElementById('courseDesc').value || null,
    type_id: document.getElementById('courseType').value ? parseInt(document.getElementById('courseType').value) : null,
    expected_chapters: document.getElementById('expectedChapters').value ? parseInt(document.getElementById('expectedChapters').value) : null,
  };
  if (id) {
    await fetch('/api/courses/' + id, { method: 'PUT', headers: {'Content-Type':'application/json'}, body: JSON.stringify(data) });
  } else {
    await fetch('/api/courses', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(data) });
  }
  closeCourseModal();
  loadCourses();
}

async function deleteCourse(id) {
  if (!confirm('确定删除此课程及其所有章节？')) return;
  await fetch('/api/courses/' + id, { method: 'DELETE' });
  loadCourses();
}

function openChapterModal(courseId) {
  document.getElementById('chapterModalTitle').textContent = '添加章节';
  document.getElementById('chapterId').value = '';
  document.getElementById('chapterCourseId').value = courseId;
  document.getElementById('chapterTitle').value = '';
  document.getElementById('chapterNumber').value = '';
  document.getElementById('chapterStatus').value = '1';
  document.getElementById('chapterDate').value = '';
  document.getElementById('chapterRemark').value = '';
  document.getElementById('deleteChapterBtn').style.display = 'none';
  document.getElementById('chapterModal').classList.add('active');
}

function editChapter(id, courseId) {
  fetch('/api/chapters/' + courseId).then(r => r.json()).then(chapters => {
    const ch = chapters.find(x => x.id === id);
    if (!ch) return;
    document.getElementById('chapterModalTitle').textContent = '编辑章节';
    document.getElementById('chapterId').value = id;
    document.getElementById('chapterCourseId').value = courseId;
    document.getElementById('chapterTitle').value = ch.title || '';
    document.getElementById('chapterNumber').value = ch.number || '';
    document.getElementById('chapterStatus').value = ch.status || 1;
    document.getElementById('chapterDate').value = ch.study_date ? ch.study_date.substring(0,10) : '';
    document.getElementById('chapterRemark').value = ch.remark || '';
    document.getElementById('deleteChapterBtn').style.display = 'block';
    document.getElementById('chapterModal').classList.add('active');
  });
}

function closeChapterModal() { document.getElementById('chapterModal').classList.remove('active'); }

async function saveChapter() {
  const id = document.getElementById('chapterId').value;
  const courseId = parseInt(document.getElementById('chapterCourseId').value);
  const dateStr = document.getElementById('chapterDate').value;
  const data = {
    course_id: courseId,
    title: document.getElementById('chapterTitle').value,
    number: document.getElementById('chapterNumber').value || null,
    status: parseInt(document.getElementById('chapterStatus').value),
    study_date: dateStr ? dateStr + 'T00:00:00.000' : null,
    remark: document.getElementById('chapterRemark').value || null,
  };
  if (id) {
    await fetch('/api/chapters/' + id, { method: 'PUT', headers: {'Content-Type':'application/json'}, body: JSON.stringify(data) });
  } else {
    await fetch('/api/chapters', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(data) });
  }
  closeChapterModal();
  toggleChapters(courseId);
  toggleChapters(courseId);
  loadCourses();
}

async function deleteChapter() {
  const id = document.getElementById('chapterId').value;
  const courseId = parseInt(document.getElementById('chapterCourseId').value);
  if (!confirm('确定删除此章节？')) return;
  await fetch('/api/chapters/' + id, { method: 'DELETE' });
  closeChapterModal();
  toggleChapters(courseId);
  toggleChapters(courseId);
  loadCourses();
}

async function deleteChapterById(id, courseId) {
  if (!confirm('确定删除此章节？')) return;
  await fetch('/api/chapters/' + id, { method: 'DELETE' });
  toggleChapters(courseId);
  toggleChapters(courseId);
  loadCourses();
}

loadTypes().then(() => loadCourses());
</script>
</body>
</html>
''';
}
