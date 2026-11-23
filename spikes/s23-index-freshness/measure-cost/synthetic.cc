// S23 synthetic TU, modelled on the S8 / S10 dry runs (deal.II + Boost).
#include <deal.II/grid/grid_generator.h>
#include <deal.II/grid/tria.h>
#include <deal.II/lac/vector.h>
#include <boost/algorithm/string.hpp>
#include <string>
#include <vector>

int main() {
  dealii::Triangulation<2> tria;
  dealii::GridGenerator::hyper_cube(tria);
  tria.refine_global(2);
  dealii::Vector<double> v(tria.n_active_cells());
  std::string s = boost::algorithm::to_upper_copy(std::string("x"));
  return v.l2_norm() > 0 && !s.empty() ? 0 : 1;
}
