import { createRouter, createWebHashHistory } from 'vue-router'
import Home from '../views/Home.vue'
import Device from '../views/Device.vue'
import Nav from '../views/Nav.vue'
import Profile from '../views/Profile.vue'
import Resource from '../views/Resource.vue'
import WorkOrders from '../views/WorkOrders.vue'

const routes = [
  { path: '/', name: 'home', component: Home },
  { path: '/device', name: 'device', component: Device },
  { path: '/nav', name: 'nav', component: Nav },
  { path: '/profile', name: 'profile', component: Profile },
  { path: '/resource', name: 'resource', component: Resource },
  { path: '/orders', name: 'orders', component: WorkOrders },
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
})

export default router
