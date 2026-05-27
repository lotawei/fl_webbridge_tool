import { createRouter, createWebHashHistory } from 'vue-router'
import Home from '../views/Home.vue'
import Device from '../views/Device.vue'
import Nav from '../views/Nav.vue'
import Profile from '../views/Profile.vue'

const routes = [
  { path: '/', name: 'home', component: Home },
  { path: '/device', name: 'device', component: Device },
  { path: '/nav', name: 'nav', component: Nav },
  { path: '/profile', name: 'profile', component: Profile },
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
})

export default router
