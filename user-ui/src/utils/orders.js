export const orderTabs = [
  ['all', '全部订单'],
  ['0', '待付款'],
  ['2', '待发货'],
  ['3', '待收货'],
  ['4', '已完成'],
  ['cancelled', '已取消'],
]
// Fetch enough of each ordered stream to produce the requested merged page.
export async function cancelledPage(fetchPage, pageNum, pageSize = 10) {
  const needed = pageNum * pageSize
  async function collect(status) {
    const rows = []
    let total = 0
    for (let index = 1; rows.length < needed; index++) {
      const result = await fetchPage({ status, pageNum: index, pageSize: 100 })
      total = result.total
      rows.push(...result.list)
      if (rows.length >= total || !result.list.length) break
    }
    return { rows, total }
  }
  const data = await Promise.all([collect(5), collect(6)])
  const rows = [
    ...new Map(data.flatMap((value) => value.rows).map((row) => [row.orderNo, row])).values(),
  ].sort(
    (a, b) =>
      String(b.createTime).localeCompare(String(a.createTime)) ||
      String(b.orderNo).localeCompare(String(a.orderNo)),
  )
  return {
    list: rows.slice((pageNum - 1) * pageSize, pageNum * pageSize),
    total: data.reduce((sum, value) => sum + value.total, 0),
  }
}
