<template>
  <a-modal :visible="visible" @cancel="$emit('close')" :footer="null" title="Select server">
    <div class="search" v-if="!loading">
      <a-input placeholder="Search servers..." style="width: 250px" v-model="input" />
    </div>
    <a-list :data-source="filteredData" :pagination="pagination" :loading="loading" ref="list">
      <a-list-item slot="renderItem" slot-scope="item" @click="$emit('select-server', item.Host)">
        {{ item.Country }}, {{ item.City }} - {{ item.Provider }}
      </a-list-item>
    </a-list>
  </a-modal>
</template>

<script>
export default {
  props: ['visible', 'data', 'loading'],
  data () {
    return {
      pagination: {
        pageSize: 10
      },
      search: '',
      timeout: null
    }
  },
  computed: {
    filteredData () {
      return this.data.filter(item => {
        const search = this.search.toLowerCase()
        try {
          return (item.Country && item.Country.toLowerCase().includes(search)) ||
          (item.City && item.City.toLowerCase().includes(this.search)) ||
          (item.Provider && item.Provider.toLowerCase().includes(this.search))
        } catch (e) {
          return false
        }
      })
    },
    // Debounced input for less lag when searching
    input: {
      get () {
        return this.search
      },
      set (val) {
        if (this.timeout) clearTimeout(this.timeout)
        this.timeout = setTimeout(() => {
          this.$refs.list.paginationCurrent = 1
          this.search = val
        }, 300)
      }
    }
  },
  beforeDestroy () {
    if (this.timeout) clearTimeout(this.timeout)
  }
}
</script>

<style scoped>
 .search {
  display: flex;
  justify-content: center;
  /* margin-top: -1rem; */
  margin-block: -1rem 0.5rem;
 }
</style>

<style>
.ant-list-items:first-child {
  border-top: 1px solid #e8e8e8;
}
.ant-list-item:hover {
  background-color: #e8e8e8;
}
.ant-list-item:active {
  background-color: #c0c0c0;
}
.ant-list-item {
  padding-inline: 12px;
}
.ant-list-pagination {
  text-align: center;
}
</style>
