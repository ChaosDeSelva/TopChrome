const drawer=document.querySelector('#drawer');
if(drawer){
 const show=document.querySelector('#show'),expand=document.querySelector('#expand');
 expand.addEventListener('click',()=>{const full=drawer.classList.toggle('expanded');expand.setAttribute('aria-pressed',String(full));document.querySelector('#height').textContent=full?'100%':'50%';});
 document.querySelector('#hide').addEventListener('click',()=>{drawer.classList.add('tucked');drawer.inert=true;show.hidden=false;show.focus({preventScroll:true});});
 show.addEventListener('click',()=>{drawer.classList.remove('tucked');drawer.inert=false;show.hidden=true;expand.focus({preventScroll:true});});
}
const destination=document.querySelector('#destination');
if(destination)destination.addEventListener('change',()=>{document.querySelector('#route').textContent=destination.value==='TopChrome'?'Example links open as tabs in the TopChrome drawer.':'Example links open in a Chrome window.';});
document.querySelector('#copy').addEventListener('click',async()=>{const status=document.querySelector('#copy-status');try{await navigator.clipboard.writeText(document.querySelector('#commands').textContent);status.textContent='Copied. Paste into Terminal to build the app.';}catch{status.textContent='Select the commands above to copy them manually.';}});
