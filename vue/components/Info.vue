<template>
  <a-col class="info">
    <a-icon :type="icon" />
    <span>{{ text || '-' }}</span>
  </a-col>
</template>

<script>
export default {
  props: ['icon', 'text', 'loading']
}
</script>

<style scoped>
.info {
  display: flex;
  font-size: 1.5rem;
}
.info > i {
  margin-right: 5px;
  font-size: 2.5rem;
}
</style>
