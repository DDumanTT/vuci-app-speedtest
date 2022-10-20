<template>
  <div>
    <div class="wrapper">
      <a-row type="flex" justify="space-around" :gutter="32">
        <info icon="user" :text="ip" />
        <info icon="global" :text="server" />
        <info icon="arrow-down" :text="`${down} Mbps`" />
        <info icon="arrow-up" :text="`${up} Mbps`" />
      </a-row>
      <a-row type="flex" justify="center">
        <vue-speedometer
          :width="750"
          :height="415"
          :maxValue="100"
          :currentValueText="`${speed} Mbps`"
          labelFontSize="24"
          valueTextFontSize="32"
          :paddingVertical="16"
          :value="speed > 100 ? 100 : speed"
          class="show-overflow"
        />
      </a-row>
      <a-row type="flex" justify="center">
        <span :style="{ 'font-size': '1.5rem', 'margin-bottom': '1rem' }">{{
          message
        }}</span>
      </a-row>
      <a-row :gutter="30" type="flex" justify="center">
        <a-col>
          <a-button
            size="large"
            type="primary"
            @click="handleStart"
            :disabled="started"
            >START</a-button
          >
        </a-col>
        <a-col>
          <a-button size="large" :disabled="started" @click="openModal">SELECT SERVER</a-button>
        </a-col>
      </a-row>
    </div>
    <server-select-modal :visible="modalVisible" @close="modalVisible = false" :data="serversList" @select-server="handleServerSelect" :loading="modalLoading" />
  </div>
</template>

<script>
import VueSpeedometer from 'vue-speedometer'
import Info from './components/Info.vue'
import ServerSelectModal from './components/ServerSelectModal.vue'

const REFRESH_SPEED = 1000 // ms

export default {
  components: { VueSpeedometer, Info, ServerSelectModal },
  data () {
    return {
      ip: '',
      server: '',
      down: '-',
      up: '-',
      started: false,
      message: '',
      speed: 0,
      modalVisible: false,
      modalLoading: true,
      serversList: [],
      timeout: null
    }
  },
  methods: {
    async handleStart () {
      this.started = true
      this.down = '-'
      this.up = '-'
      !this.ip && await this.getIpInfo()
      !this.server && await this.findBestServer()
      await this.checkAlive()
      await this.testDownload()
      await this.sleep(3000)
      await this.testUpload()
      this.message = ''
      this.started = false
    },
    async sleep (ms) {
      if (!this.started) return
      let timeoutId
      this.timeout = new Promise((resolve, reject) => {
        timeoutId = setTimeout(resolve, ms)
      })
      this.timeout.abort = () => {
        clearTimeout(timeoutId)
      }
      return this.timeout
    },
    showError (err) {
      this.started = false
      this.message = ''
      this.speed = 0
      this.timeout && this.timeout.abort()
      if (err) this.$message.error('Failed to connect to server...')
    },
    async getIpInfo () {
      this.message = 'Getting ip...'
      try {
        const r = await this.$rpc.call('speedtest', 'getIpInfo')
        if (r.status === 'failed') {
          this.showError(r.error)
          return
        }
        this.ip = `${r.query} (${r.countryCode})`
      } catch (err) {
        this.showError(err)
      }
    },
    async checkAlive () {
      if (!this.started) return
      this.message = 'Connecting...'
      try {
        const res = await this.$rpc.call('speedtest', 'alive', { host: this.server })
        if (res.status === 'failed') {
          this.showError(res.error)
        }
      } catch (err) {
        this.showError(err)
      }
    },
    async testDownload () {
      if (!this.started) return
      this.message = 'Testing download speed...'
      try {
        await this.callAndRead('download', { host: this.server }, (r) => {
          if (r.speed) this.speed = r.speed
        })
        this.down = this.speed
        this.speed = 0
      } catch (err) {
        this.showError(err)
      }
    },
    async testUpload () {
      if (!this.started) return
      this.message = 'Testing upload speed...'
      try {
        await this.callAndRead('upload', { host: this.server }, (r) => {
          if (r.speed) this.speed = r.speed
        })
        this.up = this.speed
        this.speed = 0
      } catch (err) {
        this.showError(err)
      }
    },
    async findBestServer () {
      if (!this.started) return
      this.message = 'Finding optimal server...'
      try {
        await this.callAndRead('findBestServer', {}, (r) => {
          if (r.status === 'finished') {
            this.loading = false
            this.server = r.server.Host
          }
        })
      } catch (err) {
        this.showError(err)
      }
    },
    async callAndRead (method, params, callback) {
      await this.$rpc.call('speedtest', method, params)
      return new Promise((resolve, reject) => {
        const interval = setInterval(async () => {
          const r = await this.$rpc.call('speedtest', 'readResults')
          callback(r)
          if (r.status !== 'running') {
            clearInterval(interval)
            if (r.status === 'finished') resolve()
            if (r.status === 'failed') reject(new Error(r.error))
          }
        }, REFRESH_SPEED)
      })
    },
    async openModal () {
      this.modalVisible = true
      this.serversList = await this.$rpc.call('speedtest', 'getServerList')
      this.modalLoading = false
    },
    handleServerSelect (server) {
      this.server = server
      this.modalVisible = false
    }
  }
}
</script>

<style scoped>
.wrapper {
  margin: 50px;
}
</style>

<style>
.speedometer {
  overflow: visible !important;
}
</style>
