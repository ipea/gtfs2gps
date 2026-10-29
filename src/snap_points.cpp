#include <cpp11.hpp>
#include <vector>
using namespace cpp11;

double distanceHaversine(double latf, double lonf, double latt, double lont,
                         double tolerance);
double toRadians(double deg);

std::vector<double> cpp_snap_points_nearest2_level(const doubles_matrix<>& data, const doubles_matrix<>& ref, int spatial_resolution, int level){
  std::vector<double> result_pos;

  const int nrow = data.nrow();
  const int ref_nrow = ref.nrow();

  int ref_i = -1;
  int i = 0;
  bool found;
  double dist;
  double dist_next;

  while(i < nrow && ref_i + 2 < ref_nrow) {
    const double x = data(i, 0);
    const double y = data(i, 1);
    found = false;

    do {
      ref_i++;
      const double ref_x = ref(ref_i, 0);
      const double ref_y = ref(ref_i, 1);

      dist = distanceHaversine(toRadians(y), toRadians(x), toRadians(ref_y), toRadians(ref_x), 1);

      const double ref_x_next = ref(ref_i + 1, 0);
      const double ref_y_next = ref(ref_i + 1, 1);

      dist_next = distanceHaversine(toRadians(y), toRadians(x), toRadians(ref_y_next), toRadians(ref_x_next), 1);

      if(dist < spatial_resolution && dist < dist_next){
        result_pos.push_back(ref_i + 1);
        found = true;
      }
    } while (ref_i + 2 < ref_nrow && !found);

    i++;
  }

  if((int) result_pos.size() < nrow)
    result_pos.push_back(ref_nrow - 1);

  if((int) result_pos.size() < nrow){
    if(level > 3){
      return std::vector<double>();
    }

    return cpp_snap_points_nearest2_level(data, ref, spatial_resolution * 2, level + 1);
  }

  return result_pos;
}

// Snap a set of points to the closest reference points.
// It requires that the distance from the data points to the reference
// points should be smaller than the spatial resolution and that such distance
// should be smaller than the distance to the next reference point.
// @param data A set of points to be snapped (a matrix). The result will have
// the same number of rows of this argument. Each row will return the respective
// snapped point.
// @param ref A set of reference points (another matrix). The result will be
// a subset of this parameter.
// @param spatial_resolution The spatial resolution of data, which means that from each
// point of data it is possible to reach at least one point within data with distance
// equals or less than spatial_resolution.
// @return A data.frame with the snapped points.
[[cpp11::register]]
doubles cpp_snap_points_nearest2(doubles_matrix<> data, doubles_matrix<> ref, int spatial_resolution){
  return writable::doubles(cpp_snap_points_nearest2_level(data, ref, spatial_resolution, 1));
}

std::vector<double> cpp_snap_points_nearest1_level(const doubles_matrix<>& data, const doubles_matrix<>& ref, int spatial_resolution, int level){
  std::vector<double> result_pos;

  const int nrow = data.nrow();
  const int ref_nrow = ref.nrow();
  const int ref_length = ref.nrow() * ref.ncol();
  int ref_i = -1;

  for(int i = 0; i < nrow; i++){
    const double x = data(i, 0);
    const double y = data(i, 1);
    double dist = spatial_resolution + 1;

    if(ref_i + 1 < ref_nrow && ref_i + 1 + ref_nrow < ref_length){
      do {
        ref_i++;
        const double ref_x = ref(ref_i, 0);
        const double ref_y = ref(ref_i, 1);

        dist = distanceHaversine(toRadians(y), toRadians(x), toRadians(ref_y), toRadians(ref_x), 1);
      } while (dist > spatial_resolution && ref_i + 1 < ref_nrow);
    }

    if(dist <= spatial_resolution){
      result_pos.push_back(ref_i + 1);
    }
  }

  if((int) result_pos.size() < nrow){
    if(level > 3){
      return std::vector<double>();
    }

    return cpp_snap_points_nearest1_level(data, ref, spatial_resolution * 2, level + 1);
  }

  return result_pos;
}

// Snap a set of points to the closest reference points.
// It requires that the distance from the data points to the reference
// points should be smaller than the spatial resolution.
// @param data A set of points to be snapped (a matrix). The result will have
// the same number of rows of this argument. Each row will return the respective
// snapped point.
// @param ref A set of reference points (another matrix). The result will be
// a subset of this parameter.
// @param spatial_resolution The spatial resolution of data, which means that from each
// point of data it is possible to reach at least one point within data with distance
// equals or less than spatial_resolution.
// @return A data.frame with the snapped points.
[[cpp11::register]]
doubles cpp_snap_points_nearest1(doubles_matrix<> data, doubles_matrix<> ref, int spatial_resolution){
  return writable::doubles(cpp_snap_points_nearest1_level(data, ref, spatial_resolution, 1));
}
