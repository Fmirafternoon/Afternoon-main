import { Controller } from '@hotwired/stimulus'

export default class extends Controller {

  connect() {
    setTimeout(() => {
      this.element.classList.remove('translate-x-full')
      this.element.classList.add('translate-x-0')
      this.element.classList.remove('opacity-0')
      this.element.classList.add('opacity-100')
    }, 10)

    setTimeout(() => {
      this.close()
    }, 5000)
  }

  close() {
    this.element.classList.remove('opacity-100')
    this.element.classList.add('opacity-0')
    this.element.classList.remove('translate-x-0')
    this.element.classList.add('translate-x-full')
    this.element.addEventListener('transitionend', () => {
      this.element.remove();
    });
  }
}