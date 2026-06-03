<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { brCall } from 'br-web-bridge-vue'

interface WorkOrder {
  id?: number
  title: string
  description: string
  status: string
  priority: string
  assignee?: string
  address?: string
}

const orders = ref<WorkOrder[]>([])
const loading = ref(false)
const editing = ref<WorkOrder | null>(null)
const showForm = ref(false)
const statusFilter = ref('')

const filtered = computed(() => statusFilter.value ? orders.value.filter(o => o.status === statusFilter.value) : orders.value)

async function load() {
  loading.value = true
  try {
    const r = await brCall('database.workOrder.query') as any
    if (r.ok) orders.value = r.rows
  } catch (e: any) { console.error(e) }
  finally { loading.value = false }
}

async function save() {
  if (!editing.value) return
  loading.value = true
  try {
    if (editing.value.id) {
      await brCall('database.workOrder.update', { ...editing.value })
    } else {
      await brCall('database.workOrder.insert', { ...editing.value })
    }
    showForm.value = false
    await load()
  } finally { loading.value = false }
}

async function remove(id: number) {
  if (!confirm('确定删除这条工单？')) return
  await brCall('database.workOrder.delete', { id })
  await load()
}

function create() { editing.value = { title: '', description: '', status: 'pending', priority: 'medium' }; showForm.value = true }
function edit(o: WorkOrder) { editing.value = { ...o }; showForm.value = true }
function cancel() { showForm.value = false; editing.value = null }

const statusLabels: Record<string, string> = { pending: '⏳ 待处理', in_progress: '🔧 处理中', completed: '✅ 已完成' }
const priorityLabels: Record<string, string> = { high: '🔴 高', medium: '🟡 中', low: '🟢 低' }

onMounted(load)
</script>

<template>
  <div class="page">
    <div class="header-row">
      <h2>📋 离线工单</h2>
      <button class="btn-sm" @click="create">+ 新建工单</button>
    </div>

    <div class="filters">
      <label v-for="(label, key) in { '': '全部', pending: '⏳ 待处理', in_progress: '🔧 处理中', completed: '✅ 已完成' }" :key="key" :class="{ active: statusFilter === key }" @click="statusFilter = key">
        {{ label }}
      </label>
    </div>

    <div v-if="loading" class="loading">加载中...</div>

    <div v-else class="list">
      <div class="card" v-for="o in filtered" :key="o.id">
        <div class="card-head">
          <strong>{{ o.title }}</strong>
          <span class="prio">{{ priorityLabels[o.priority] || o.priority }}</span>
        </div>
        <p class="desc">{{ o.description }}</p>
        <div class="meta">
          <span>{{ statusLabels[o.status] || o.status }}</span>
          <span v-if="o.assignee">👤 {{ o.assignee }}</span>
          <span v-if="o.address">📍 {{ o.address }}</span>
        </div>
        <div class="actions">
          <button class="btn-sm outline" @click="edit(o)">编辑</button>
          <button class="btn-sm danger" @click="remove(o.id!)">删除</button>
        </div>
      </div>
      <div v-if="!filtered.length" class="empty">暂无工单</div>
    </div>

    <div class="modal" v-if="showForm">
      <div class="modal-content">
        <h3>{{ editing!.id ? '编辑工单' : '新建工单' }}</h3>
        <label>标题 <input v-model="editing!.title" placeholder="工单标题" /></label>
        <label>描述 <textarea v-model="editing!.description" placeholder="详细描述" rows="3" /></label>
        <label>状态 <select v-model="editing!.status"><option value="pending">待处理</option><option value="in_progress">处理中</option><option value="completed">已完成</option></select></label>
        <label>优先级 <select v-model="editing!.priority"><option value="high">高</option><option value="medium">中</option><option value="low">低</option></select></label>
        <label>负责人 <input v-model="editing!.assignee" placeholder="姓名" /></label>
        <label>地址 <input v-model="editing!.address" placeholder="工单地址" /></label>
        <div class="form-actions">
          <button @click="cancel">取消</button>
          <button class="primary" @click="save">保存</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.page { padding: 16px; padding-bottom: 80px; }
.header-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
h2 { font-size: 20px; }
.btn-sm { padding: 6px 14px; border: 0; border-radius: 6px; background: #2563eb; color: white; font-size: 13px; cursor: pointer; }
.btn-sm.outline { background: transparent; color: #2563eb; border: 1.5px solid #2563eb; }
.btn-sm.danger { background: #ef4444; }
.filters { display: flex; gap: 6px; margin-bottom: 14px; flex-wrap: wrap; }
.filters label { padding: 4px 10px; border-radius: 14px; font-size: 12px; background: #f1f5f9; color: #475569; cursor: pointer; }
.filters label.active { background: #2563eb; color: white; }
.loading { text-align: center; padding: 40px; color: #94a3b8; }
.empty { text-align: center; padding: 40px; color: #94a3b8; }
.card { padding: 14px; background: #fff; border-radius: 8px; border: 1px solid #e7e9ef; margin-bottom: 10px; }
.card-head { display: flex; justify-content: space-between; margin-bottom: 6px; }
.card-head strong { font-size: 15px; }
.prio { font-size: 12px; }
.desc { font-size: 13px; color: #475569; margin-bottom: 8px; }
.meta { display: flex; gap: 12px; font-size: 12px; color: #94a3b8; }
.actions { display: flex; gap: 8px; margin-top: 10px; }

.modal { position: fixed; inset: 0; background: rgba(0,0,0,.4); display: flex; align-items: center; justify-content: center; z-index: 100; }
.modal-content { background: #fff; border-radius: 12px; padding: 20px; width: 90%; max-width: 400px; max-height: 80vh; overflow: auto; }
.modal-content h3 { margin-bottom: 14px; }
.modal-content label { display: block; margin-bottom: 10px; font-size: 13px; color: #475569; }
.modal-content input, .modal-content textarea, .modal-content select { width: 100%; padding: 8px; margin-top: 4px; border: 1px solid #e7e9ef; border-radius: 6px; font-size: 14px; }
.form-actions { display: flex; gap: 8px; margin-top: 16px; }
.form-actions button { flex: 1; padding: 10px; border: 0; border-radius: 6px; font-size: 14px; cursor: pointer; background: #f1f5f9; color: #475569; }
.form-actions button.primary { background: #2563eb; color: white; }
</style>
