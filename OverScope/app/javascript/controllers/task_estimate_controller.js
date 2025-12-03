import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["estimate"]

  connect() {
    // Auto-estimate on page load if estimate is empty
    if (this.hasEstimateTarget && !this.estimateTarget.value) {
      this.estimate()
    }
  }

  estimate() {
    const complexity = this.element.querySelector('select[name*="complexity"]')?.value || 3
    const priority = this.element.querySelector('input[name*="priority"]')?.value || 3
    const dueDate = this.element.querySelector('input[name*="due_date"]')?.value || null
    const taskId = this.element.querySelector('input[type="hidden"][name*="id"]')?.value || 
                   this.element.closest('form')?.querySelector('input[type="hidden"][name*="id"]')?.value

    const params = new URLSearchParams({
      task_id: taskId || 'new',
      priority: priority,
      complexity: complexity
    })
    if (dueDate) params.append('due_date', dueDate)

    // Show loading state
    const originalValue = this.estimateTarget.value
    this.estimateTarget.value = '...'
    this.estimateTarget.disabled = true

    fetch(`/api/tasks/estimate?${params.toString()}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
      }
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      console.log('Estimation response:', data)
      // Handle both camelCase and snake_case
      const estimate = data.estimateHours || data.estimate_hours || data.estimate
      if (estimate) {
        this.estimateTarget.value = estimate
        // Show a brief success indicator
        this.estimateTarget.style.backgroundColor = '#d1fae5'
        setTimeout(() => {
          this.estimateTarget.style.backgroundColor = ''
        }, 1000)
      } else {
        console.warn('No estimate found in response:', data)
        // Fallback to complexity-based estimate
        const complexityMap = { 1: 2, 2: 4, 3: 8, 4: 16, 5: 32 }
        this.estimateTarget.value = complexityMap[complexity] || 8
      }
    })
    .catch(error => {
      console.error('Error estimating task:', error)
      // Fallback to complexity-based estimate
      const complexityMap = { 1: 2, 2: 4, 3: 8, 4: 16, 5: 32 }
      this.estimateTarget.value = complexityMap[complexity] || 8
    })
    .finally(() => {
      this.estimateTarget.disabled = false
    })
  }
}

